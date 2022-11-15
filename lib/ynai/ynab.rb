# frozen_string_literal: true

require 'ynab'

module Ynai
  class YNAB
    def initialize(config)
      @config = config
    end

    def client
      @client = ::YNAB::API.new(@config['push.token']) unless @client

      @client
    end

    def accounts
      budget_response = client.budgets.get_budgets include_accounts: true
      budget_data = budget_response.data.budgets

      accounts = []
      budget_data.each do |budget|
        budget.accounts.each do |account|
          accounts << {
            id: account.id,
            budget_id: budget.id,
            name: "#{budget.name} - #{account.name}"
          }
        end
      end

      accounts
    end

    def create_transactions(budget_id, transactions)
      begin
        res = client.transactions.create_transactions(budget_id, { 'transactions' => transactions })

        res&.data&.duplicate_import_ids || []
      rescue YNAB::ApiError => e
        puts e.name
        puts e.detail
        exit!
      end
    end
  end
end
