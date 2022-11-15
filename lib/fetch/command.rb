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
        @client = Nordigen::NordigenClient.new(
          secret_id: @config['fetch.secret_id'],
          secret_key: @config['fetch.secret_key']
        )
        @config.configurator.nordigen = @client
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
          @config.delete 'fetch.access_token'
          @client.set_token @config['fetch.access_token']
          retry
        elsif attempt == 3
          puts 'Failed'
          puts 'Getting new token'
          @config.delete 'fetch.access_token'
          @config.delete 'fetch.refresh_token'
          @client.set_token @config['fetch.access_token']
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
