# frozen_string_literal: true

require_relative '../lib/config'
require_relative '../lib/database'

describe Ynai::Config do
  before(:each) do
    @db = Ynai::Database.get('/tmp/yani-test.db')
  end

  after(:all) do
    File.delete('/tmp/yani-test.db')
  end

  it 'saves data in the database' do
    config = Ynai::Config.new(@db)

    expect(config.has?('test')).to eq(false)
    config['test'] = 'banana'
    expect(config.has?('test')).to eq(true)
    expect(config['test']).to eq('banana')
    config.delete('test')
    expect(config.has?('test')).to eq(false)
  end
end
