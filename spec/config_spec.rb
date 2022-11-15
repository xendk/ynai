# frozen_string_literal: true

require_relative '../lib/ynai/config'
require_relative '../lib/ynai/database'

describe Ynai::Config do
  before(:each) do
    @db = Ynai::Database.get('/tmp/yani-test.db')
  end

  after(:all) do
    File.delete('/tmp/yani-test.db')
  end

  it 'saves data in the database' do
    config = Ynai::Config.new(@db, double('configurator'))

    expect(config.has?('test')).to eq(false)
    config['test'] = 'banana'
    expect(config.has?('test')).to eq(true)
    expect(config['test']).to eq('banana')
    config.delete('test')
    expect(config.has?('test')).to eq(false)

  end

  it 'asks configurator on unknown items' do
    configurator = double('configurator')
    config = Ynai::Config.new(@db, configurator)

    expect(configurator).to receive(:get).once().with('unknown') { 'generated value' }

    expect(config['unknown']).to eq('generated value')
    # Should return the same on second call, but not call the configurator again.
    expect(config['unknown']).to eq('generated value')
  end
end
