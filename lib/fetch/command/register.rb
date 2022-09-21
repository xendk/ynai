# frozen_string_literal: true

module Fetch
  # Registration command.
  class Command::Register < Command
    def run
      ensure_tokens

      ensure_connection

      ensure_instution

      ensure_requsition

      req = client.requisition.get_requisition_by_id @config[:requsition_id]

      raise 'Error fetching requisition' unless req.id

      puts 'Fetching accounts'
      req.accounts.each do |id|
        details = client.account(id).get_details
        db do |db|
          sql = 'INSERT OR REPLACE INTO accounts (id, name, product) VALUES (?, ?, ?)'
          db.execute(sql, [id, details.account.name, details.account.product])
        end
      end

      puts "#{req.accounts.size} accounts set up."
      puts 'All set up. Now run `fetch run`.'
    end

    def ensure_instution
      return if @config.has?(:institution_id)

      print 'Enter country code (ISO 3166) or press return for all: '
      country = gets.chomp
      institutions = client.institution.get_institutions(country)
      institution_ids = []
      institutions.each do |inst|
        institution_ids << inst.id
        puts "#{inst.id}: #{inst.name}"
      end

      print 'Enter bank ID (hopefully you have scrollback): '
      institution_id = gets.chomp
      raise 'Invalid institution ID' unless institution_ids.include? institution_id

      @config[:institution_id] = institution_id
      @config.save!
    end

    def ensure_requsition
      return if @config.has?(:requsition_id)

      @config[:reference_id] = SecureRandom.uuid
      requsition = client.init_session(
        redirect_url: 'https://google.com',
        institution_id: @config[:institution_id],
        reference_id: @config[:reference_id]
      )
      @config[:requsition_id] = requsition['id']
      @config.save!

      puts "Now visit: #{requsition['link']}"
      puts 'And re-run this command when you hit google.com.'

      exit
    end
  end
end
