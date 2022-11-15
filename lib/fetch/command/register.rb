# frozen_string_literal: true

module Fetch
  # Registration command.
  class Command::Register < Command
    def run
      req = client.requisition.get_requisition_by_id @config['fetch.requsition_id']

      raise 'Error fetching requisition' unless req['id']

      puts 'Fetching accounts'
      req['accounts']&.each do |id|
        details = client.account(id).get_details
        db do |db|
          # Some banks doesn't give a product.
          db[:accounts].insert(
            id: id,
            name: details.dig('account', 'name'),
            product: details.dig('account', 'product') || ''
          )
        end
      end

      puts "#{req['accounts'].size} accounts set up."
      puts 'All set up. Now run `fetch run`.'
    end
  end
end
