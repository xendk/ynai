# frozen_string_literal: true

module Fetch
  # Run command.
  class Command::Run < Command
    def run
      ensure_connection

      insert = db.prepare <<~SQL
        INSERT OR IGNORE INTO transactions (
          id,
          account_id,
          state,
          booking_date,
          amount,
          currency,
          description,
          value_date,
          balance,
          balance_currency
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      SQL
      res = db.execute('SELECT id FROM accounts')
      res.each do |row|
        account_id, * = row

        transactions = client.account(account_id).get_transactions
        transactions.transactions.booked.each do |transaction|
          insert.execute(
            transaction.transactionId,
            account_id,
            'pending',
            transaction.bookingDate,
            transaction.transactionAmount.amount,
            transaction.transactionAmount.currency,
            transaction.additionalInformation,
            # Apparently some cleared transactions doesn't have a
            # value date. Seems to occur on transactions between
            # accounts (and perhaps only new ones).
            transaction.valueDate || transaction.bookingDate,
            transaction.balanceAfterTransaction.balanceAmount.amount,
            transaction.balanceAfterTransaction.balanceAmount.currency
          )
        end
      end
    end
  end
end
