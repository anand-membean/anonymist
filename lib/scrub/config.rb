# frozen_string_literal: true

require "yaml"

module Scrub
  class Config
    attr_reader :tables
    attr_accessor :bloom_filter_options

    def initialize
      @tables = {}
      @bloom_filter_options = { size: 1_000_000, hashes: 5, seed: 1, bucket: 8, raise: false }
    end

    def load_file(path)
      if path.end_with?(".yml", ".yaml")
        load_yaml(path)
      elsif path.end_with?(".rb")
        load_ruby(path)
      else
        raise ArgumentError, "Unsupported configuration format: #{path}"
      end
    end

    def table(name, &block)
      @tables[name.to_s] ||= TableConfig.new(name)
      block.call(@tables[name.to_s]) if block_given?
      @tables[name.to_s]
    end

    def validate!
      raise ArgumentError, "No tables configured" if @tables.empty?

      @tables.each do |name, table|
        raise ArgumentError, "Table '#{name}' has no columns configured" if table.sorted_columns.empty?
      end
    end

    private def load_yaml(path)
      data = YAML.load_file(path)
      return unless data

      if data["bloom_filter"]
        @bloom_filter_options = @bloom_filter_options.merge(symbolize_keys(data["bloom_filter"]))
      end

      return unless data["tables"]

      data["tables"].each do |table_name, table_data|
        table(table_name) do |t|
          next unless table_data["columns"]

          raw_columns = table_data["columns"]
          columns = if raw_columns.is_a?(Array)
            raw_columns.each_with_object({}) do |col, acc|
              acc[col.keys.first] = col.values.first
            end
          else
            raw_columns
          end

          columns.each do |col_name, col_data|
            # col_data might be just the type string or a hash
            options = if col_data.is_a?(Hash)
              symbolize_keys(col_data)
            else
              { type: col_data }
            end
            t.column(col_name, **options)
          end
        end
      end
    end

    private def load_ruby(path)
      instance_eval(File.read(path), path)
    end

    private def symbolize_keys(hash)
      hash.transform_keys(&:to_sym)
    end
  end
end
