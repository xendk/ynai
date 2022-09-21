# frozen_string_literal: true

require 'yaml'

# Handle the config.
class Config
  attr_reader :path

  def initialize(path, filename)
    @path = path
    @filename = File.join(path, filename)

    unless File.exist? @filename
      @config = {}
      return
    end

    begin
      @config = YAML.safe_load(File.read(@filename), symbolize_names: true)

      # Make sub-hashes be string indexed.
      @config.transform_values! do |val|
        if val.is_a? Hash
          val.transform_keys! { |key| key.to_s}
        end
        val
      end
    rescue StandardError => e
      abort "Error loading config file: #{e.message}"
    end
  end

  def save!
    data = {}
    @config.each_pair do |key, val|
      data[key.to_s] = val
    end

    File.write(@filename, data.to_yaml)
  end

  def has?(key)
    @config.key? key
  end

  def [](key)
    @config[key]
  end

  def []=(key, val)
    @config[key] = val
  end

  def delete(key)
    @config.delete(key)
  end
end
