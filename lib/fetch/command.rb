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
          secret_id: @config[:secret_id],
          secret_key: @config[:secret_key]
        )
      end

      @client.set_token @config[:access_token] if @config.has? :access_token

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
      return if @config.has?(:secret_id) && @config.has?(:secret_key)

      print 'Enter secret id: '
      @config[:secret_id] = gets.chomp

      print 'Enter secret key: '
      @config[:secret_key] = gets.chomp

      @config.save!
    end

    def ensure_tokens
      return if @config.has?(:access_token) && @config.has?(:refresh_token)

      token = client.generate_token

      @config[:access_token] = token['access']
      @config[:refresh_token] = token['refresh']

      @config.save!
    end

    def refresh_token
      @config[:access_token] = client.exchange_token(@config[:refresh_token])['access']
      @config.save!
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
          @config.delete :access_token
          ensure_tokens
          retry
        else
          # Remove invalid tokens.
          @config.delete(:access_token)
          @config.delete(:refresh_token)
          @config.save!

          raise 'Error getting token'
        end
      end
    end
  end
end

require_relative 'command/register'
require_relative 'command/run'
