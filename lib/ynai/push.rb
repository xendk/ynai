# frozen_string_literal: true

require 'ynab'

require_relative 'config'
require_relative 'database'

module Ynai
  # Class for the push command.
  class Push
    def initialize(config, db, ynab)
      @config = config
      @db = db
      @ynab = ynab
    end

    def run()
      processed_ids = []
      transactions = {}

      @config['push.mapping'].each do |mapping|
        nordigen_account_id = mapping['nordigen_account_id']
        ynab_account_id = mapping['ynab_account_id']
        budget_id = mapping['budget_id']
        transactions[budget_id] = [] unless transactions.has_key? budget_id
        @db[:transactions]
          .select(:id, :booking_date, :amount, :description, :import_id)
          .where(state: 'pending')
          .where(account_id: nordigen_account_id)
          .exclude(value_date: nil)
          .all do |row|
          transactions[budget_id] << {
            'account_id' => ynab_account_id,
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

      duplicated_ids = []
      transactions.each_pair do |budget_id, budget_transactions|
        duplicated_ids += @ynab.create_transactions(budget_id, budget_transactions)
      end

      processed_ids.each do |id|
        @db[:transactions].where(id: id).update(state: 'processed')
      end

      puts "Duplicated IDs: #{duplicated_ids.join(', ')}" unless duplicated_ids.empty?
    end
  end
end
