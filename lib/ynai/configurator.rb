# frozen_string_literal: true

require 'json'
require 'securerandom'

module Ynai
  # The configurator, who knows how to configure stuff.
  class Configurator
    attr_writer :config, :db, :nordigen, :ynab

    def initialize
      @stack = []
    end

    # Configure an item.
    def get(name)
      method = "configure_#{name.gsub(/\./, '__')}"
      raise "Don't know how to configure \"#{name}\"" unless respond_to? method

      raise "Cyclic configuration dependencies: #{@stack.join(', ')}" if @stack.include? name

      @stack << name
      val = send method
      @stack.pop
      val
    end

    def config
      raise "No config available to configure \"#{@stack.last}\"" unless @config

      @config
    end

    def db
      raise "No db available to configure \"#{@stack.last}\"" unless @db

      @db
    end

    def nordigen
      raise "No Nordigen client available to configure \"#{@stack.last}\"" unless @nordigen

      @nordigen
    end

    def ynab
      raise "No YNAB client available to configure \"#{@stack.last}\"" unless @ynab

      @ynab
    end

    # Helper for just asking the user.
    def ask(prompt)
      print "\n#{prompt}: "
      gets.chomp
    end

    def configure_fetch__secret_id
      ask 'Enter secret id'
    end

    def configure_fetch__secret_key
      ask 'Enter secret key'
    end

    def configure_fetch__refresh_token
      token = nordigen.generate_token

      @config['fetch.access_token'] = token['access'] if @config

      token['refresh']
    end

    def configure_fetch__access_token
      if @config&.has?('fetch.refresh_token')
        nordigen.exchange_token @config['fetch.refresh_token']
      else
        token = nordigen.generate_token

        @config['fetch.refresh_token'] = token['refresh'] if @config

        token['access']
      end
    end

    def configure_fetch__institution_id
      country = ask 'Enter country code (ISO 3166) or press return for all'

      institutions = nordigen.institution.get_institutions(country)
      institution_ids = []
      puts
      institutions.each do |inst|
        institution_ids << inst['id']
        puts "#{inst['id']}: #{inst['name']}"
      end

      institution_id = ask 'Enter bank ID (hopefully you have scrollback)'
      raise 'Invalid institution ID' unless institution_ids.include? institution_id

      institution_id
    end

    def configure_fetch__requisition_id
      requisition = nordigen.init_session(
        redirect_url: 'https://google.com',
        institution_id: config['fetch.institution_id'],
        reference_id: SecureRandom.uuid
      )
      @config['fetch.requisition_id'] = requisition['id']

      puts
      puts "Now visit: #{requisition['link']}"
      puts 'And re-run this command when you hit google.com.'

      exit
    end

    def configure_fetch__accounts
      req = nordigen.requisition.get_requisition_by_id config['fetch.requisition_id']

      raise 'Error fetching requisition' unless req['id']

      accounts = []
      puts 'Fetching accounts'
      req['accounts']&.each do |id|
        details = nordigen.account(id).get_details
        accounts << {
          id: id,
          name: details.dig('account', 'name'),
          # Some banks doesn't give a product.
          product: details.dig('account', 'product') || ''
        }
      end

      puts
      puts "#{req['accounts'].size} accounts set up."
      puts 'All set up. Now run `fetch run`.'

      accounts
    end

    def configure_push__token
      ask 'Enter personal access token'
    end

    def configure_push__accounts
      ynab.accounts.map do |account|
        new_account = {}

        account.each_pair do |key, val|
          new_account[key.to_s] = val
        end

        new_account
      end
    end

    def configure_push__mapping
      number = 1
      accounts = {}
      prompt = "\n"
      config['push.accounts'].each do |account|
        accounts[number] = account
        prompt += "#{number}: #{account['name']}\n"
        number += 1
      end

      prompt += "(Return to not import this account)\n"

      mapping = []
      summary = []

      db[:accounts].select(:id, :name).all do |id:, name:|
        puts prompt
        print "Import \"#{name}\" into: "

        choice = gets.chomp
        if choice == ''
          summary << "#{name} => <not imported>"
          next
        end

        choice = choice.to_i
        raise 'Invalid selection' unless accounts.include? choice

        mapping << {
          'nordigen_account_id': id,
          'ynab_account_id': accounts[choice]['id'],
          'budget_id': accounts[choice]['budget_id']
        }

        summary << "#{name} => #{accounts[choice]['name']}"
      end

      puts
      puts 'Mapping bank account => YNAB account:'
      summary.each do |line|
        puts line
      end
      print 'Is this OK? (y/n) '
      raise 'Canceled' unless gets.chomp =~ /y/

      mapping
    end
  end
end
