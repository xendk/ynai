# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:transactions) do
      add_column :original_data, String, text: true, default: ''
    end
  end
end
