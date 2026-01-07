# lib/scrub/runner.rb
module Scrub
  class Runner
    def initialize(db_config, dry_run: false)
      @dry_run = dry_run
      @read_client = DbAdapters.connect(db_config)
      @write_client = DbAdapters.connect(db_config) unless @dry_run
    end

    def run
      Scrub.config.tables.each do |table_name, table_config|
        scrub_table(table_name, table_config)
      end
    end

    private

    def scrub_table(table_name, table_config)
      puts "Scrubbing table: #{table_name}"

      primary_key = @read_client.primary_key(table_name)
      puts "Detected Primary Key: #{primary_key}"

      rows = @read_client.query(
        "SELECT * FROM #{table_name}",
        stream: true,
        cache_rows: false
      )

      rows.each do |row|
        updates = {}

        table_config.columns.each do |column, block|
          updates[column] = block.call(row)
        end

        next if updates.empty?

        set_clause = updates.map do |col, val|
          "#{col} = #{sql_literal(val)}"
        end.join(", ")

        pk_value = row[primary_key]
        where_clause =
          pk_value.is_a?(Numeric) ? pk_value : sql_literal(pk_value)

        query = <<~SQL.gsub(/\s+/, " ").strip
          UPDATE #{table_name}
          SET #{set_clause}
          WHERE #{primary_key} = #{where_clause}
        SQL

        if @dry_run
          puts "[DRY RUN] #{query}"
        else
          @write_client.query(query)
        end
      end
    end

    def sql_literal(val)
      return "NULL" if val.nil?
      return val.to_s if val.is_a?(Numeric)
      "'#{@read_client.escape(val.to_s)}'"
    end
  end
end
