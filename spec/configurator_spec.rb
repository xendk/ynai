# frozen_string_literal: true

require_relative '../lib/ynai/configurator'

# rubocop:disable Style/SingleLineMethods
describe Ynai::Configurator do
  it 'raises on unknown configuration items' do
    configurator = Ynai::Configurator.new
    expect { configurator.get('unknown') }.to raise_error('Don\'t know how to configure "unknown"')
  end

  it 'calls the configure_<thing> method' do
    configurator = Ynai::Configurator.new

    def configurator.configure_thing() 'the thing' end

    expect(configurator.get('thing')).to eq('the thing')
  end

  it 'raises on recursive calls' do
    configurator = Ynai::Configurator.new

    def configurator.configure_thing() get('other_thing') end
    def configurator.configure_other_thing() get('thing') end

    expect { configurator.get('thing') }.to raise_error('Cyclic configuration dependencies: thing, other_thing')
  end

  it 'raises if missing a Nordigen client' do
    configurator = Ynai::Configurator.new

    expect { configurator.get('fetch.access_token') }
      .to raise_error('No Nordigen client available to configure "fetch.access_token"')
  end

  it 'raises if missing a YNAB client' do
    configurator = Ynai::Configurator.new

    expect { configurator.get('push.accounts') }
      .to raise_error('No YNAB client available to configure "push.accounts"')
  end

  context 'for fetch it' do
    it 'can configure fetch.secret_id' do
      configurator = Ynai::Configurator.new

      expect(configurator).to receive(:print).with('Enter secret id: ')
      expect(configurator).to receive(:gets) { "secret\n" }

      expect(configurator.get('fetch.secret_id')).to eq('secret')
    end

    it 'can configure fetch.secret_key' do
      configurator = Ynai::Configurator.new

      expect(configurator).to receive(:print).with('Enter secret key: ')
      expect(configurator).to receive(:gets) { "secret key\n" }

      expect(configurator.get('fetch.secret_key')).to eq('secret key')
    end

    it 'can configure fetch.refresh_token' do
      configurator = Ynai::Configurator.new

      nordigen = double('nordigen')
      token_response = { 'access' => 'the access token', 'refresh' => 'the refresh token' }
      expect(nordigen).to receive(:generate_token).and_return(token_response)

      config = double('config')
      expect(config).to receive(:[]=).with('fetch.access_token', 'the access token')

      configurator.nordigen = nordigen
      configurator.config = config

      expect(configurator.get('fetch.refresh_token')).to eq('the refresh token')
    end

    it 'can configure fetch.access_token without refresh token' do
      configurator = Ynai::Configurator.new

      nordigen = double('nordigen')
      token_response = { 'access' => 'the access token', 'refresh' => 'the refresh token' }
      expect(nordigen).to receive(:generate_token).and_return(token_response)

      config = double('config')
      expect(config).to receive(:has?).with('fetch.refresh_token') { false }
      expect(config).to receive(:[]=).with('fetch.refresh_token', 'the refresh token')

      configurator.nordigen = nordigen
      configurator.config = config

      expect(configurator.get('fetch.access_token')).to eq('the access token')
    end

    it 'can configure fetch.access_token with refresh token' do
      configurator = Ynai::Configurator.new

      nordigen = double('nordigen')
      expect(nordigen).to receive(:exchange_token).and_return('the access token')

      config = double('config')
      expect(config).to receive(:has?).with('fetch.refresh_token') { true }
      expect(config).to receive(:[]).with('fetch.refresh_token') { 'the refresh token' }

      configurator.nordigen = nordigen
      configurator.config = config

      expect(configurator.get('fetch.access_token')).to eq('the access token')
    end

    it 'can configure fetch.institution_id' do
      configurator = Ynai::Configurator.new

      nordigen = double('nordigen')
      institution_reply = [
        {
          'id' => 'BANKID1',
          'name' => 'Bank 1'
        },
        {
          'id' => 'BANKID2',
          'name' => 'Bank 2'
        }
      ]

      expect(nordigen).to receive_message_chain(:institution, :get_institutions).and_return(institution_reply)

      configurator.nordigen = nordigen

      expect(configurator).to receive(:print).with('Enter country code (ISO 3166) or press return for all: ')
      expect(configurator).to receive(:print).with('Enter bank ID (hopefully you have scrollback): ')
      expect(configurator).to receive(:puts).with('BANKID1: Bank 1')
      expect(configurator).to receive(:puts).with('BANKID2: Bank 2')
      expect(configurator).to receive(:gets).and_return("dk\n", "BANKID2\n")

      expect(configurator.get('fetch.institution_id')).to eq('BANKID2')
    end

    it 'can raises on fetch.institution_id when selecting invalid institution' do
      configurator = Ynai::Configurator.new

      nordigen = double('nordigen')
      institution_reply = [
        {
          'id' => 'BANKID1',
          'name' => 'Bank 1'
        },
        {
          'id' => 'BANKID2',
          'name' => 'Bank 2'
        }
      ]

      expect(nordigen).to receive_message_chain(:institution, :get_institutions).and_return(institution_reply)

      configurator.nordigen = nordigen

      expect(configurator).to receive(:print).with('Enter country code (ISO 3166) or press return for all: ')
      expect(configurator).to receive(:print).with('Enter bank ID (hopefully you have scrollback): ')
      expect(configurator).to receive(:puts).with('BANKID1: Bank 1')
      expect(configurator).to receive(:puts).with('BANKID2: Bank 2')
      expect(configurator).to receive(:gets).and_return("dk\n", "BANKID3\n")

      expect { configurator.get('fetch.institution_id') }.to raise_error('Invalid institution ID')
    end

    it 'can configure fetch.requisition_id' do
      nordigen = double('nordigen')
      expect(nordigen).to receive(:init_session).and_return({
                                                              'id' => 'req_id',
                                                              'link' => 'https://the.link'
                                                            })

      config = double('config')
      expect(config).to receive(:[]).with('fetch.institution_id') { 'the institution' }
      expect(config).to receive(:[]=).with('fetch.requisition_id', 'req_id')

      configurator = Ynai::Configurator.new
      expect(configurator).to receive(:puts).with('Now visit: https://the.link')
      expect(configurator).to receive(:puts).with('And re-run this command when you hit google.com.')

      configurator.nordigen = nordigen
      configurator.config = config

      expect { configurator.get('fetch.requisition_id') }.to raise_error(SystemExit)
    end

    it 'can configure fetch.accounts' do
      nordigen = double('nordigen')
      expect(nordigen)
        .to receive_message_chain(:requisition, :get_requisition_by_id)
              .with('req_id')
              .and_return({
                            'id' => 'req_id',
                            'accounts' => %w[id1 id2]
                          })

      res1 = double
      res2 = double
      expect(res1).to receive(:get_details).and_return({ 'account' => {
                                                           'name' => 'name 1',
                                                           'product' => 'product 1'
                                                         }})
      expect(res2).to receive(:get_details).and_return({ 'account' => {
                                                           'name' => 'name 2'
                                                         }})
      expect(nordigen).to receive(:account).with('id1') { res1 }
      expect(nordigen).to receive(:account).with('id2') { res2 }

      config = double('config')
      expect(config).to receive(:[]).with('fetch.requisition_id') { 'req_id' }

      configurator = Ynai::Configurator.new
      configurator.nordigen = nordigen
      configurator.config = config

      expect(configurator).to receive(:puts).with('Fetching accounts')
      expect(configurator).to receive(:puts).with('2 accounts set up.')
      expect(configurator).to receive(:puts).with('All set up. Now run `fetch run`.')

      expect(configurator.get('fetch.accounts'))
        .to eq([
                 {
                   id: 'id1',
                   name: 'name 1',
                   product: 'product 1'
                 },
                 {
                   id: 'id2',
                   name: 'name 2',
                   product: ''
                 }
               ])
    end
  end

  context 'for push it' do
    it 'can configure push.token' do
      configurator = Ynai::Configurator.new

      expect(configurator).to receive(:print).with('Enter personal access token: ')
      expect(configurator).to receive(:gets) { "token\n" }

      expect(configurator.get('push.token')).to eq('token')
    end

    it 'can configure push.accounts' do
      configurator = Ynai::Configurator.new

      accounts = [
        { id: '1', budget_id: '2', name: 'first'},
        { id: '2', budget_id: '3', name: 'second'},
      ]

      ynab = double('ynab')
      expect(ynab).to receive(:accounts).and_return(
        [
          { id: '1', budget_id: '2', name: 'first'},
          { id: '2', budget_id: '3', name: 'second'},
        ]
      )

      configurator.ynab = ynab

      expect(configurator.get('push.accounts')).to eq(
        [
          { 'id' => '1', 'budget_id' => '2', 'name' => 'first'},
          { 'id' => '2', 'budget_id' => '3', 'name' => 'second'},
        ])
    end

    it 'can configure push.mapping' do
      configurator = Ynai::Configurator.new

      db = double('db')
      select = double
      expect(select).to receive(:all)
        .and_yield({ id: '123', name: 'le first'})
        .and_yield({ id: '456', name: 'le second'})
        .and_yield({ id: '789', name: 'le third'})
      expect(db).to receive(:[]).with(:accounts) { double('table', select: select) }

      ynab_accounts = [
        { 'id' => '1', 'budget_id' => '2', 'name' => 'first'},
        { 'id' => '2', 'budget_id' => '3', 'name' => 'second'},
        { 'id' => '3', 'budget_id' => '3', 'name' => 'third'},
      ]

      config = double('config')
      expect(config).to receive(:[]).with('push.accounts') { ynab_accounts }

      configurator.config = config
      configurator.db = db

      expect(configurator).to receive(:puts).with("1: first\n2: second\n3: third\n(Return to not import this account)\n").exactly(3).times
      expect(configurator).to receive(:print).with('Import "le first" into: ')
      expect(configurator).to receive(:print).with('Import "le second" into: ')
      expect(configurator).to receive(:print).with('Import "le third" into: ')
      expect(configurator).to receive(:print).with('Is this OK? (y/n) ')
      expect(configurator).to receive(:gets).and_return("1\n", "2\n", "\n",  "y\n")
      expect(configurator).to receive(:puts).with('Mapping bank account => YNAB account:')
      expect(configurator).to receive(:puts).with('le first => first')
      expect(configurator).to receive(:puts).with('le second => second')
      expect(configurator).to receive(:puts).with('le third => <not imported>')

      expect(configurator.get('push.mapping')).to eq(
        [
          { nordigen_account_id: '123', ynab_account_id: '1', budget_id: '2' },
          { nordigen_account_id: '456', ynab_account_id: '2', budget_id: '3' }
        ]
      )
    end
  end
end
# rubocop:enable Style/SingleLineMethods
