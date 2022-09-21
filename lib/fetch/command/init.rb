# frozen_string_literal: true

require 'sqlite3'

module Fetch

  # Database init command.
  class Command::Init < Command
    def run
      db do |db|
        db.execute <<~SQL
          CREATE TABLE IF NOT EXISTS accounts (
            id TEXT PRIMARY KEY NOT NULL,
            name TEXT NOT NULL,
            product TEXT NOT NULL
          );
        SQL
        db.execute <<~SQL
          CREATE TABLE IF NOT EXISTS transactions (
            id TEXT PRIMARY KEY NOT NULL,
            account_id TEXT NOT NULL,
            state TEXT CHECK( state IN ('pending', 'processed') ),
            booking_date TEXT NOT NULL,
            amount REAL NOT NULL,
            currency TEXT NOT NULL,
            description TEXT NOT NULL,
            value_date TEXT,
            balance REAL,
            balance_currency TEXT
          );
        SQL

        puts 'Database set up. Now run `fetch register`.'
      end
    end
  end
end
