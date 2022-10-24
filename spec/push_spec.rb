# frozen_string_literal: true

require_relative '../lib/push'

describe Ynai::Push do
  it 'should push transactions when configured' do
    # We'll just use a Hash instead of mocking config.
    config = {
      token: 'ynab-token',
      budget_mapping: { 'a123' => 'b123', 'a321' => 'b321' },
      accounts: { 'a123' => 'budget1 - first account', 'a321' => 'budget2 - second account' },
      mapping: { 'ba213' => 'a123', 'ba312' => 'a321' }
    }
    # Make Hash look like a Config.
    config.class.send(:alias_method, :has?, :has_key?)

    db = double('Sequel::Database')

    res1 = double
    expect(res1).to receive_message_chain(:exclude, :all)
      .and_yield(
        {
          id: 't1',
          booking_date: '2022-10-24',
          amount: 5,
          description: 'first transaction',
          import_id: 'i1'
        }
      )
      .and_yield(
        {
          id: 't2',
          booking_date: '2022-10-24',
          amount: 1.99,
          description: 'second transaction',
          import_id: 'i2'
        }
      )

    res2 = double
    expect(res2).to receive_message_chain(:exclude, :all)
      .and_yield(
        {
          id: 't3',
          booking_date: '2022-10-23',
          amount: 11,
          description: 'second account transaction',
          import_id: 'i3'
        }
      )

    # We're using allow for some of these method chains, else rspec
    # complains about the number of times they're called, and we can't
    # use `at_least` and co. with receive_message_chain. As we're
    # checking that the expected request is sent to YNAB, we'll ignore
    # the details here.
    allow(db).to receive_message_chain(:[], :select, :where, :where).with({ account_id: 'ba213' }) { res1 }
    allow(db).to receive_message_chain(:[], :select, :where, :where).with({ account_id: 'ba312' }) { res2 }

    client = double('client')
    res = double('res')
    expect(YNAB::API).to receive(:new).with('ynab-token') { client }

    allow(res).to receive_message_chain('data.duplicate_import_ids.empty?') { true }
    trans1 = double
    trans2 = double

    expect(trans1).to receive('create_transactions')
      .with('b123',
            {
              'transactions' => [
                {
                  'account_id' => 'a123',
                  'date' => '2022-10-24',
                  'amount' => 5000,
                  'payee_name' => 'first transaction',
                  'cleared' => 'cleared',
                  'import_id' => 'i1'
                },
                {
                  'account_id' => 'a123',
                  'date' => '2022-10-24',
                  'amount' => 1990,
                  'payee_name' => 'second transaction',
                  'cleared' => 'cleared',
                  'import_id' => 'i2'
                }
              ]
            }) { res }

    expect(trans2).to receive('create_transactions')
      .with('b321',
            {
              'transactions' => [
                {
                  'account_id' => 'a321',
                  'date' => '2022-10-23',
                  'amount' => 11_000,
                  'payee_name' => 'second account transaction',
                  'cleared' => 'cleared',
                  'import_id' => 'i3'
                }
              ]
            }) { res }

    expect(client).to receive(:transactions).and_return(trans1, trans2)
    allow(db).to receive_message_chain(:[], :where, :update).with(state: 'processed')

    push = Ynai::Push.new(config, db)
    push.run(false, false)
    end
end
