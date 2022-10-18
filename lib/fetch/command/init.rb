# frozen_string_literal: true

module Fetch
  # Database init command.
  class Command::Init < Command
    def run
      Sequel.extension :migration
      db do |db|
        # Start at 1 if we have a legacy database without schema_info.
        if db.table_exists?(:transactions) && !db.table_exists?(:schema_info)
          Sequel::Migrator.run(db, 'migrations', current: 1)
          # If there's no migrations past 1, the schema version gets
          # set to 0, so update it.
          db[:schema_info].where(version: 0).update(version: 1)
        else
          Sequel::Migrator.run(db, 'migrations')
        end
      end
      puts 'Database set up. Now run `fetch register`.'
    end
  end
end
