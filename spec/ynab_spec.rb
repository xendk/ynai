# frozen_string_literal: true

require_relative '../lib/ynai/ynab'

describe Ynai::YNAB do
  before(:example) do
    @client = double('ynab')
    @config = double('config')
    allow(@config).to receive(:[]).with('push.token') { 'token' }
    allow(YNAB::API).to receive(:new).with('token') { @client }

    @ynab = Ynai::YNAB.new(@config)
  end

  it 'initializes with a token when called' do
    expect(@config).to receive(:[]).with('push.token') { 'token' }
    expect(YNAB::API).to receive(:new).with('token')

    get_budgets_response = double('get_budget_response')
    expect(get_budgets_response).to receive_message_chain(:data, :budgets).and_return([])

    expect(@client).to receive_message_chain(:budgets, :get_budgets)
      .with(include_accounts: true) { get_budgets_response }

    @ynab.accounts
  end

  it 'returns accounts' do
    get_budgets_response = double('get_budget_response')
    budgets = [
      double(
        'budget',
        id: 'b123',
        name: 'My budget',
        accounts: [
          double(id: 'a123', name: 'first account'),
          double(id: 'a234', name: 'second account')
        ]
      ),
      double(
        'budget',
        id: 'b234',
        name: 'My second budget',
        accounts: [
          double(id: 'a456', name: 'third account')
        ]
      )
    ]
    expect(get_budgets_response).to receive_message_chain(:data, :budgets).and_return(budgets)

    expect(@client).to receive_message_chain(:budgets, :get_budgets)
      .with(include_accounts: true) { get_budgets_response }
    expect(@ynab.accounts).to eq(
      [
        { id: 'a123', budget_id: 'b123', name: 'My budget - first account' },
        { id: 'a234', budget_id: 'b123', name: 'My budget - second account' },
        { id: 'a456', budget_id: 'b234', name: 'My second budget - third account' }
      ]
    )
  end

  it 'pushes transactions' do
    budget_id = '123'
    transactions = [
      {
        'account_id' => '123',
        'date' => '2022-11-05',
        'amount' => 10_000,
        'payee_name' => 'some description',
        'cleared' => 'cleared',
        'import_id' => 'import_id1'
      },
      {
        'account_id' => '143',
        'date' => '2022-11-05',
        'amount' => 5_000,
        'payee_name' => 'some other description',
        'cleared' => 'cleared',
        'import_id' => 'import_id2'
      }
    ]
    expect(@client).to receive_message_chain(:transactions, :create_transactions)
      .with(budget_id, { 'transactions' => transactions}) {
        double('res', data: double(duplicate_import_ids: []))
      }

    expect(@ynab.create_transactions(budget_id, transactions)).to eq([])
  end

  it 'returns duplicated transactions' do
    budget_id = '123'
    transactions = [
      {
        'account_id' => '123',
        'date' => '2022-11-05',
        'amount' => 10_000,
        'payee_name' => 'some description',
        'cleared' => 'cleared',
        'import_id' => 'import_id1'
      }
    ]
    expect(@client).to receive_message_chain(:transactions, :create_transactions)
      .with(budget_id, { 'transactions' => transactions}) {
        double('res', data: double(duplicate_import_ids: ['123']))
      }

    expect(@ynab.create_transactions(budget_id, transactions)).to eq(['123'])
  end
end
