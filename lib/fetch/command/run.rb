# frozen_string_literal: true

require 'digest'

module Fetch
  # Run command.
  class Command::Run < Command
    def run
      ensure_connection

      latest = db.get_first_value('SELECT MAX(booking_date) FROM transactions')

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
          balance_currency,
          import_id
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      SQL
      res = db.execute('SELECT id FROM accounts')
      res.each do |row|
        account_id, * = row

        transactions = client.account(account_id).get_transactions
        transactions.transactions.booked.each do |transaction|
          # Skip existing transactions, but process the last day in
          # case more cropped up.
          next if latest && transaction.bookingDate < latest

          # The transaction IDs are too big for import_id, so we hash
          # it and cut it down to size. We prefix by the date, which
          # increases the chance of hash collisions, but means we can
          # never collide with a past transaction. The risk of
          # collision would probably be lower just using as much hash
          # as possible, but this feels better.
          import_id = (transaction.bookingDate + Digest::SHA1.hexdigest(transaction.transactionId))[0..35]

          # Not all banks supply these.
          balance_amount = transaction.balanceAfterTransaction&.balanceAmount&.amount || 0
          balance_currency = transaction.balanceAfterTransaction&.balanceAmount&.currency || ''

          # Differences in "description" between banks.
          description = transaction.remittanceInformationUnstructured&.split(/\n/)&.first ||
                        transaction.additionalInformation

          insert.execute(
            transaction.transactionId,
            account_id,
            'pending',
            transaction.bookingDate,
            transaction.transactionAmount.amount,
            transaction.transactionAmount.currency,
            description,
            # Apparently some cleared transactions doesn't have a
            # value date. Seems to occur on transactions between
            # accounts (and perhaps only new ones).
            transaction.valueDate || transaction.bookingDate,
            balance_amount,
            balance_currency,
            import_id
          )
        end
      end
    end
  end
end
