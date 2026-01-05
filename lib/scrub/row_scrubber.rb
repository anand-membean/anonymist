# frozen_string_literal: true

module Scrub
  class RowScrubber
    def initialize(table_config)
      @table_config = table_config
    end

    # row: Hash of column_name => value
    # context: :dump or :live
    # validator_factory: Proc that takes (column_config, row) and returns a validator block
    # Returns: Updated row hash
    def scrub(row, _context = nil, &validator_factory)
      # Determine columns to scrub in dependency order
      # Only consider columns present in the row
      columns_to_scrub = @table_config.sorted_columns.select { |c| row.key?(c.name) }

      columns_to_scrub.each do |column_config|
        col_name = column_config.name
        original_val = row[col_name]

        # Get validator for this column/row context
        validator = validator_factory.call(column_config, row)

        scrubbed_val = column_config.scrubber.scrub(original_val, row, &validator)

        # Update row hash so subsequent columns see the scrubbed value
        row[col_name] = scrubbed_val
      end

      row
    end
  end
end
