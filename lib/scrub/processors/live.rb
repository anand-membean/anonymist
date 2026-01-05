# frozen_string_literal: true

require "ruby-progressbar"
require "bloomfilter-rb"

module Scrub
  module Processors
    class Live
      def initialize(config, db_config, dry_run: false)
        @config = config
        @db_config = db_config
        @dry_run = dry_run
        @read_client = DbAdapters.connect(db_config)
        @write_client = DbAdapters.connect(db_config) unless @dry_run
      end

      def run
        @config.tables.each do |table_name, table_config|
          process_table(table_name, table_config)
        end
      end

      private def process_table(table_name, table_config)
        puts "Scrubbing table: #{table_name}"

        # Detect Primary Key
        primary_key = @read_client.primary_key(table_name)
        puts "Detected Primary Key: #{primary_key}"

        # Count rows for progress bar
        count_result = @read_client.query("SELECT COUNT(*) as count FROM #{table_name}")
        total_rows = count_result.first["count"]

        # Detect Unique Columns for Bloom Filter
        unique_cols = @read_client.unique_columns(table_name)
        scrubbed_cols = table_config.sorted_columns.map(&:name)
        cols_needing_uniqueness = unique_cols & scrubbed_cols

        bloom = nil
        if cols_needing_uniqueness.any?
          puts "Initializing Bloom Filter for unique columns: #{cols_needing_uniqueness.join(', ')}"
          # Heuristic: size = total_rows * num_cols * 10 (to be safe) or minimum 100k
          bf_size = [total_rows * cols_needing_uniqueness.size * 10, 100_000].max
          bloom = BloomFilter::Native.new(size: bf_size, hashes: 5, seed: 1, bucket: 8, raise: false)
        end

        progress = ProgressBar.create(
          title: table_name,
          total: total_rows,
          format: "%t: |%B| %p%% %e"
        )

        # Fetch rows with streaming to avoid memory issues
        results = @read_client.query("SELECT * FROM #{table_name}", stream: true, cache_rows: false)

        results.each do |row|
          process_row(row, table_name, table_config, primary_key, bloom, cols_needing_uniqueness)
          progress.increment
        end
        progress.finish
      end

      private def process_row(row, table_name, table_config, primary_key, bloom, unique_cols)
        max_retries = 5
        retries = 0

        begin
          # Work on a copy so we can retry with original data if needed
          working_row = row.dup
          updates = {}

          scrubber = RowScrubber.new(table_config)
          # Optimistic scrubbing: assume valid, catch collision at DB commit
          # If bloom filter is present, use it to check uniqueness
          scrubber.scrub(working_row, :live) do |column_config, _current_row|
            if bloom && unique_cols.include?(column_config.name)
              lambda do |candidate|
                key = "#{column_config.name}:#{candidate}"
                if bloom.include?(key)
                  false
                else
                  bloom.insert(key)
                  true
                end
              end
            else
              lambda { |_candidate| true }
            end
          end

          # Collect updates for configured columns
          table_config.sorted_columns.each do |col_config|
            col_name = col_config.name
            next unless working_row.key?(col_name)

            new_val = working_row[col_name]
            updates[col_name] = new_val
          end

          return if updates.empty?

          update_db_row(table_name, primary_key, row[primary_key], updates)
        rescue => e
          if @write_client&.duplicate_entry_error?(e) && retries < max_retries
            retries += 1
            # puts "Collision detected for #{table_name} ID #{row[primary_key]}. Retrying (#{retries}/#{max_retries})..."
            retry
          elsif e.is_a?(@read_client.connection_error_class)
            puts "Failed to scrub row #{row[primary_key]}: #{e.message}"
            raise e
          else
            raise e
          end
        end
      end

      private def update_db_row(table, pk_col, pk_val, updates)
        set_clause = updates.map do |col, val|
          "#{col} = '#{@read_client.escape(val)}'"
        end.join(", ")

        query = "UPDATE #{table} SET #{set_clause} WHERE #{pk_col} = #{pk_val}"

        if @dry_run
          puts "[DRY RUN] #{query}"
        else
          # puts "Executing: #{query}" # Verbose logging
          @write_client.query(query)
        end
      end
    end
  end
end
