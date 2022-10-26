# frozen_string_literal: true

require 'json'

module Ynai
  # Handle the config.
  class Config
    attr_reader :path

    def initialize(db)
      @db = db
    end

    def has?(key)
      !@db[:config][name: key].nil?
    end

    def [](key)
      JSON.parse(@db[:config][name: key][:value])
    end

    def []=(key, val)
      json = val.to_json
      row = @db[:config].where(name: key)
      @db[:config].insert(name: key, value: json) unless row.update(value: json) == 1
    end

    def delete(key)
      @db[:config].where(name: key).delete
    end
  end
end
