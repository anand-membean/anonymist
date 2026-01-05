# frozen_string_literal: true

require "bloomfilter-rb"

module Scrub
  module Processors
    class Dump
      def initialize(config)
        @config = config
        # Initialize BloomFilter for uniqueness check
        @bloom = BloomFilter::Native.new(@config.bloom_filter_options)
      end

      def process(input_stream, output_stream)
        input_stream.each_line do |line|
          if line.start_with?("INSERT INTO")
            output_stream.write(process_insert(line))
          else
            output_stream.write(line)
          end
        end
      end

      private def process_insert(line)
        # Regex to capture table name.
        match = line.match(/INSERT INTO `?(\w+)`? \((.*?)\) VALUES (.*);/)
        return line unless match

        table_name = match[1]
        columns_str = match[2]
        values_str = match[3]

        return line unless @config.tables.key?(table_name)

        table_config = @config.tables[table_name]

        # Map column names to indices
        col_map = columns_str.split(",").map(&:strip).map { |c| c.gsub("`", "") }

        # Split value groups: (1, 'a'), (2, 'b')
        rows = values_str.split(/\),\s*\(/)

        new_rows = rows.map do |row_str|
          # Clean leading/trailing parens for first/last elements
          clean_row = row_str.sub(/^\(/, "").sub(/\)$/, "")

          # Split values by comma, respecting quotes (simplified)
          values = clean_row.split(/,(?=(?:[^']*'[^']*')*[^']*$)/).map(&:strip)

          # Create a row hash for context (unquoting values)
          row_hash = col_map.zip(values.map { |v| v.gsub(/^'|'$/, "") }).to_h

          scrubber = RowScrubber.new(table_config)
          scrubber.scrub(row_hash, :dump) do |_column_config, _row|
            lambda do |candidate|
              if !@bloom.include?(candidate)
                @bloom.insert(candidate)
                true
              else
                false
              end
            end
          end

          # Update values array for output
          row_hash.each do |col_name, val|
            index = col_map.index(col_name)
            # Escape single quotes in the value
            escaped_val = val.gsub("'", "\\\\'")
            values[index] = "'#{escaped_val}'"
          end

          values.join(", ")
        end

        "INSERT INTO `#{table_name}` (#{columns_str}) VALUES (#{new_rows.join('), (')});\n"
      end
    end
  end
end
