# frozen_string_literal: true

require "spec_helper"

RSpec.describe Scrub::RowScrubber do
  let(:table_config) { instance_double(Scrub::TableConfig) }
  let(:row_scrubber) { described_class.new(table_config) }
  let(:col1) { instance_double(Scrub::ColumnConfig, name: "col1") }
  let(:col2) { instance_double(Scrub::ColumnConfig, name: "col2") }
  let(:scrubber1) { instance_double(Scrub::Scrubber) }
  let(:scrubber2) { instance_double(Scrub::Scrubber) }

  before do
    allow(table_config).to receive(:sorted_columns).and_return([col1, col2])
    allow(col1).to receive(:scrubber).and_return(scrubber1)
    allow(col2).to receive(:scrubber).and_return(scrubber2)
  end

  describe "#scrub" do
    it "scrubs columns present in the row" do
      row = { "col1" => "val1", "col2" => "val2" }

      allow(scrubber1).to receive(:scrub).with("val1", row).and_return("scrubbed1")
      allow(scrubber2).to receive(:scrub).with("val2", row).and_return("scrubbed2")

      result = row_scrubber.scrub(row) do |col, r|
        # Verify validator factory is called
        expect(r).to eq(row)
        proc { true }
      end

      expect(result["col1"]).to eq("scrubbed1")
      expect(result["col2"]).to eq("scrubbed2")
    end

    it "skips columns not in the row" do
      row = { "col1" => "val1" }

      allow(scrubber1).to receive(:scrub).with("val1", row).and_return("scrubbed1")
      allow(scrubber2).to receive(:scrub)

      row_scrubber.scrub(row) { proc { true } }

      expect(scrubber2).not_to have_received(:scrub)
    end

    it "updates row context for subsequent columns" do
      row = { "col1" => "val1", "col2" => "val2" }

      # First column scrub updates the row
      allow(scrubber1).to receive(:scrub) do |val, r, &blk|
        "scrubbed1"
      end

      # Second column should see the updated row
      allow(scrubber2).to receive(:scrub) do |val, r, &blk|
        expect(r["col1"]).to eq("scrubbed1")
        "scrubbed2"
      end

      row_scrubber.scrub(row) { proc { true } }
    end
  end
end
