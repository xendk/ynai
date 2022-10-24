# frozen_string_literal: true

require 'ynab'

require_relative 'config'
require_relative 'database'

module Ynai
  # Class for the push command.
  class Push
    def initialize(config, db)
      @config = config
      @db = db
    end

    def run(refresh_accounts, update_mapping)
      unless @config.has?(:token)
        print 'Enter personal access token: '
        @config[:token] = gets.chomp
        @config.save!
      end

      ynab_api = YNAB::API.new(@config[:token])

      if @config.has?(:budget_id)
        @config.delete(:budget_id)
        @config.save!
      end

      if refresh_accounts || !@config.has?(:accounts) || !@config.has?(:budget_mapping)
        budget_response = ynab_api.budgets.get_budgets include_accounts: true
        budget_data = budget_response.data.budgets

        accounts = {}
        budget_mapping = {}
        budget_data.each do |budget|
          budget.accounts.each do |account|
            accounts[account.id] = "#{budget.name} - #{account.name}"
            budget_mapping[account.id] = budget.id
          end
        end

        @config[:accounts] = accounts
        @config[:budget_mapping] = budget_mapping
        @config.save!
      end

      number = 1
      accounts = {}
      prompt = ''
      @config[:accounts].each do |id, name|
        accounts[number] = [id, name]
        prompt += "#{number}: #{name}\n"
        number += 1
      end

      prompt += "(Return to not import this account)\n"

      if update_mapping || !@config.has?(:mapping)
        mapping = {}
        summary = []

        @db[:accounts].select(:id, :name).all do |id:, name:|
          puts prompt
          puts "Import \"#{name}\" into: "

          choice = gets.chomp
          if choice == ''
            summary << "#{name} => <not imported>"
            next
          end

          choice = choice.to_i
          raise 'Invalid selection' unless accounts.include? choice

          mapping[id] = accounts[choice][0]
          summary << "#{name} => #{accounts[choice][1]}"
        end

        puts 'Mapping bank account => YNAB account:'
        summary.each do |line|
          puts line
        end
        print 'Is this OK? (y/n) '
        raise 'Canceled' unless gets.chomp =~ /y/

        @config[:mapping] = mapping
        @config.save!
      end

      processed_ids = []
      transactions = {}

      @config[:mapping].each_key do |account|
        ynab_account = @config[:mapping][account]
        budget_id = @config[:budget_mapping][ynab_account]
        transactions[budget_id] = []
        @db[:transactions]
          .select(:id, :booking_date, :amount, :description, :import_id)
          .where(state: 'pending')
          .where(account_id: account)
          .exclude(value_date: nil)
          .all do |row|
          transactions[budget_id] << {
            'account_id' => ynab_account,
            'date' => row[:booking_date],
            'amount' => (row[:amount] * 1000).to_i,
            'payee_name' => row[:description],
            'cleared' => 'cleared',
            'import_id' => row[:import_id]
          }

          processed_ids << row[:id]
        end
      end

      transactions.filter! { |_, v| !v.empty? }
      if transactions.empty?
        puts 'No new transactions'
        exit
      end

      res = nil
      begin
        transactions.each_pair do |budget_id, budget_transactions|
          res = ynab_api.transactions.create_transactions(budget_id, { 'transactions' => budget_transactions })
        end
      rescue YNAB::ApiError => e
        puts e.name
        puts e.detail
        exit!
      end

      processed_ids.each do |id|
        @db[:transactions].where(id: id).update(state: 'processed')
      end

      return unless res.data.duplicate_import_ids && !res.data.duplicate_import_ids.empty?

      puts "Duplicated IDs: #{res.data.duplicate_import_ids.join(', ')}"
    end
  end
end
