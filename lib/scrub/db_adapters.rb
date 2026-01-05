# frozen_string_literal: true

require_relative "db_adapters/mysql"

module Scrub
  module DbAdapters
    def self.connect(config)
      # Simple detection based on config keys or explicit adapter option
      # For now, default to MySQL as it's the only one implemented
      adapter = config[:adapter] || :mysql

      case adapter.to_s.downcase
      when "mysql", "mysql2"
        Mysql.new(config)
      else
        raise ArgumentError, "Unsupported database adapter: #{adapter}"
      end
    end
  end
end
