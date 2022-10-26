# frozen_string_literal: true

# Fetch specific classes.
module Fetch
  # Superclass for fetch commands.
  class Command
    def initialize(config)
      @config = config
    end

    def client
      unless @client
        ensure_secrets

        @client = Nordigen::NordigenClient.new(
          secret_id: @config['fetch.secret_id'],
          secret_key: @config['fetch.secret_key']
        )
      end

      @client.set_token @config['fetch.access_token'] if @config.has? 'fetch.access_token'

      @client
    end

    def db
      @db ||= Ynai::Database.get

      if block_given?
        yield @db
      else
        @db
      end
    end

    def ensure_secrets
      return if @config.has?('fetch.secret_id') && @config.has?('fetch.secret_key')

      print 'Enter secret id: '
      @config['fetch.secret_id'] = gets.chomp

      print 'Enter secret key: '
      @config['fetch.secret_key'] = gets.chomp
    end

    def ensure_tokens
      return if @config.has?('fetch.access_token') && @config.has?('fetch.refresh_token')

      token = client.generate_token

      @config['fetch.access_token'] = token['access']
      @config['fetch.refresh_token'] = token['refresh']
    end

    def refresh_token
      @config['fetch.access_token'] = client.exchange_token(@config['fetch.refresh_token'])['access']
    end

    def ensure_connection
      attempt = 1
      begin
        # Check that we have a valid token. We need to create our own
        # request so we can get the HTTP status code.
        res = client.request.get('agreements/enduser/', { limit: 1, offset: 0 })
        raise "No access: #{res.body['summary']}" if res.status == 401
      rescue RuntimeError
        attempt += 1
        if attempt == 2
          puts 'Refreshing token'
          refresh_token
          retry
        elsif attempt == 3
          puts 'Failed'
          puts 'Getting new token'
          @config.delete 'fetch.access_token'
          ensure_tokens
          retry
        else
          # Remove invalid tokens.
          @config.delete('fetch.access_token')
          @config.delete('fetch.refresh_token')

          raise 'Error getting token'
        end
      end
    end
  end
end

require_relative 'command/register'
require_relative 'command/run'
