# frozen_string_literal: true

require 'digest'
require 'yaml'

module Fetch
  # Run command.
  class Command::Run < Command
    def run
      ensure_connection

      today = Time.new().strftime('%Y-%m-%d')
      latest = db[:transactions].max(:booking_date)

      db[:accounts].select(:id).all do |row|
        account_id = row[:id]

        transactions = client.account(account_id).get_transactions
        unless transactions['transactions']
          puts 'Error fetching transactions'
          puts transactions['summary'] if transactions['summary']
          puts transactions['detail'] if transactions['detail']
          exit!
        end

        transactions.dig('transactions', 'booked')&.each do |transaction|
          # Skip existing transactions, but process the last day in
          # case more cropped up.
          next if latest && transaction['bookingDate'] < latest

          # The transaction IDs are too big for import_id, so we hash
          # it and cut it down to size. We prefix by the date, which
          # increases the chance of hash collisions, but means we can
          # never collide with a past transaction. The risk of
          # collision would probably be lower just using as much hash
          # as possible, but this feels better.
          import_id = (transaction['bookingDate'] + Digest::SHA1.hexdigest(transaction['transactionId']))[0..35]

          # Not all banks supply these.
          balance_amount = transaction.dig('balanceAfterTransaction', 'balanceAmount', 'amount') || 0
          balance_currency = transaction.dig('balanceAfterTransaction', 'balanceAmount', 'currency') || ''

          # Differences in "description" between banks.
          description = transaction['remittanceInformationUnstructured']&.split(/\n/)&.first ||
            transaction['additionalInformation']

          # Wouldn't expect booking dates in the future, but it's been
          # seen. YNAB doesn't like them, so clamp them down to today.
          booking_date = transaction['bookingDate']
          booking_date = today if booking_date > today

          db[:transactions].insert_ignore.insert(
            id: transaction['transactionId'],
            account_id: account_id,
            state: 'pending',
            booking_date: booking_date,
            amount: transaction.dig('transactionAmount', 'amount'),
            currency: transaction.dig('transactionAmount', 'currency'),
            description: description,
            # Apparently some cleared transactions doesn't have a
            # value date. Seems to occur on transactions between
            # accounts (and perhaps only new ones).
            value_date: transaction['valueDate'] || transaction['bookingDate'],
            balance: balance_amount,
            balance_currency: balance_currency,
            import_id: import_id,
            original_data: transaction.to_yaml
          )
        end
      end
    end
  end
end
