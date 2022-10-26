# frozen_string_literal: true

require 'json'
require 'yaml'

def get_config(file)
  config = nil
  filename = File.join(File.dirname(__dir__), file)
  if File.exist? filename
    begin
      config = YAML.safe_load(File.read(filename), symbolize_names: true)

      # Make sub-hashes be string indexed.
      config.transform_values! do |val|
        val.transform_keys!(&:to_s) if val.is_a? Hash
        val
      end
    rescue StandardError => e
      abort "Error loading config file: #{e.message}"
    end
  end
  config
end

Sequel.migration do
  up do
    create_table(:config) do
      String :name, null: false
      String :value, text: true, null: false
    end

    %w[fetch push].each do |tool|
      config = get_config(".#{tool}.yml")
      config&.each_pair do |key, val|
        from(:config).insert(
          name: "#{tool}.#{key}",
          value: val.to_json
        )
      end
    end
  end
end
