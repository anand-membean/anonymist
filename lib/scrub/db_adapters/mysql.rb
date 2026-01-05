# frozen_string_literal: true

module Scrub
  module DbAdapters
    class Mysql
      def initialize(config)
        require "mysql2"
        @client = Mysql2::Client.new(config)
      rescue LoadError
        raise LoadError, "The 'mysql2' gem is required for MySQL support. Please install it."
      end

      def query(sql, **)
        @client.query(sql, **)
      end

      def escape(value)
        @client.escape(value)
      end

      def connection_error_class
        Mysql2::Error
      end

      def duplicate_entry_error?(error)
        error.is_a?(Mysql2::Error) && error.error_number == 1062
      end

      def primary_key(table_name)
        # Query information_schema to find the primary key
        sql = <<~SQL
          SELECT COLUMN_NAME
          FROM information_schema.COLUMNS
          WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = '#{escape(table_name)}'
          AND COLUMN_KEY = 'PRI'
          LIMIT 1
        SQL
        result = query(sql)
        result.first&.[]("COLUMN_NAME") || "id" # Fallback to 'id'
      end

      def unique_columns(table_name)
        sql = <<~SQL
          SELECT COLUMN_NAME
          FROM information_schema.STATISTICS
          WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = '#{escape(table_name)}'
          AND NON_UNIQUE = 0
        SQL
        query(sql).map { |row| row["COLUMN_NAME"] }.uniq
      end
    end
  end
end
