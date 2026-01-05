# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe Scrub::Config do
  let(:config) { described_class.new }

  describe "#initialize" do
    it "sets default bloom filter options" do
      expect(config.bloom_filter_options).to include(size: 1_000_000, hashes: 5)
    end
  end

  describe "#load_file" do
    context "with YAML file" do
      it "loads bloom filter options" do
        file = Tempfile.new(["config", ".yml"])
        file.write(<<~YAML)
          bloom_filter:
            size: 5000
            hashes: 3
          tables:
        YAML
        file.close

        config.load_file(file.path)
        expect(config.bloom_filter_options).to include(size: 5000, hashes: 3)
      end

      it "loads from .yaml extension" do
        file = Tempfile.new(["config", ".yaml"])
        file.write("tables: {}")
        file.close
        expect { config.load_file(file.path) }.not_to raise_error
      end
    end

    context "with Ruby file" do
      it "allows modifying bloom filter options via instance access" do
        file = Tempfile.new(["config", ".rb"])
        file.write(<<~RUBY)
          bloom_filter_options[:size] = 2000
        RUBY
        file.close

        config.load_file(file.path)
        expect(config.bloom_filter_options[:size]).to eq(2000)
      end
    end

    context "with unsupported file extension" do
      it "raises ArgumentError" do
        expect { config.load_file("config.txt") }.to raise_error(ArgumentError, /Unsupported configuration format/)
      end
    end
  end

  describe "#table" do
    it "creates a table config if it doesn't exist" do
      config.table(:users)
      expect(config.tables["users"]).to be_a(Scrub::TableConfig)
    end

    it "yields the table config if block given" do
      expect { |b| config.table(:users, &b) }.to yield_with_args(Scrub::TableConfig)
    end

    it "returns existing table config if already defined" do
      t1 = config.table(:users)
      t2 = config.table(:users)
      expect(t1).to equal(t2)
    end
  end

  describe "#validate!" do
    it "raises error if no tables configured" do
      expect { config.validate! }.to raise_error(ArgumentError, /No tables configured/)
    end

    it "raises error if table has no columns" do
      config.table(:users)
      expect { config.validate! }.to raise_error(ArgumentError, /Table 'users' has no columns/)
    end

    it "does not raise error if valid" do
      config.table(:users) do |t|
        t.column :email, type: :email
      end
      expect { config.validate! }.not_to raise_error
    end
  end

  describe "YAML loading edge cases" do
    it "handles empty file" do
      file = Tempfile.new(["empty", ".yml"])
      file.close
      expect { config.load_file(file.path) }.not_to raise_error
    end

    it "handles columns defined as array of hashes" do
      file = Tempfile.new(["array_cols", ".yml"])
      file.write(<<~YAML)
        tables:
          users:
            columns:
              - email:
                  type: email
              - name:
                  type: name
      YAML
      file.close

      config.load_file(file.path)
      expect(config.tables["users"].columns.keys).to include("email", "name")
    end

    it "handles file without bloom_filter" do
      file = Tempfile.new(["no_bloom", ".yml"])
      file.write("tables: {}")
      file.close
      config.load_file(file.path)
      expect(config.bloom_filter_options[:size]).to eq(1_000_000) # Default
    end

    it "handles file without tables" do
      file = Tempfile.new(["no_tables", ".yml"])
      file.write("bloom_filter: { size: 100 }")
      file.close
      config.load_file(file.path)
      expect(config.tables).to be_empty
    end

    it "handles table without columns" do
      file = Tempfile.new(["no_cols", ".yml"])
      file.write(<<~YAML)
        tables:
          users:
            other_option: true
      YAML
      file.close
      config.load_file(file.path)
      expect(config.tables["users"]).to be_a(Scrub::TableConfig)
      expect(config.tables["users"].sorted_columns).to be_empty
    end

    it "handles column defined as string" do
      file = Tempfile.new(["string_col", ".yml"])
      file.write(<<~YAML)
        tables:
          users:
            columns:
              email: email
      YAML
      file.close
      config.load_file(file.path)
      expect(config.tables["users"].sorted_columns.first.type).to eq(:email)
    end

    it "handles column defined as hash" do
      file = Tempfile.new(["hash_col", ".yml"])
      file.write(<<~YAML)
        tables:
          users:
            columns:
              email:
                type: email
                domain: custom.com
      YAML
      file.close
      config.load_file(file.path)
      col = config.tables["users"].sorted_columns.first
      expect(col.type).to eq(:email)
      expect(col.options[:domain]).to eq("custom.com")
    end
  end
end
