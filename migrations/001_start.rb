# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:accounts) do
      String :id, text: true, null: false
      String :name, text: true, null: false
      String :product, text: true, null: false

      primary_key [:id]
    end

    create_table(:transactions) do
      String :id, text: true, null: false
      String :account_id, text: true, null: false
      String :state, text: true
      constraint(:state_enum, state: ['pending', 'processed'])
      String :booking_date, text: true, null: false
      Float :amount, null: false
      String :currency, text: true, null: false
      String :description, text: true, null: false
      String :value_date, text: true
      Float :balance
      String :balance_currency, text: true
      String :import_id, text: true

      primary_key [:id]
    end
  end
end
