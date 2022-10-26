# frozen_string_literal: true

require 'sequel'

module Ynai
  # Database module.
  module Database
    def self.get(file = 'ynai.db')
      db = Sequel.sqlite(file)

      Sequel.extension :migration
      # Start at 1 if we have a legacy database without schema_info.
      if db.table_exists?(:transactions) && !db.table_exists?(:schema_info)
        Sequel::Migrator.run(db, 'migrations', current: 1)
        # If there's no migrations past 1, the schema version gets
        # set to 0, so update it.
        db[:schema_info].where(version: 0).update(version: 1)
      else
        Sequel::Migrator.run(db, 'migrations')
      end

      db
    end
  end
end
