# frozen_string_literal: true

require "spec_helper"

# Mock Mysql2 if not available
unless defined?(Mysql2)
  module Mysql2
    class Client
      def initialize(opts); end
      def query(sql, opts = {}); end
      def escape(str); end
    end

    class Error < StandardError
      attr_reader :error_number

      def initialize(msg, error_number = nil)
        super(msg)
        @error_number = error_number
      end
    end
  end
end

RSpec.describe Scrub::Processors::Live do
  let(:config) { Scrub::Config.new }
  let(:db_config) { { host: "localhost", adapter: "mysql" } }
  let(:client) { instance_double("Scrub::DbAdapters::Mysql") }

  before do
    allow(Scrub::DbAdapters).to receive(:connect).and_return(client)
    allow(client).to receive(:escape) { |val| "escaped_#{val}" }
    allow(client).to receive(:duplicate_entry_error?) { |e| e.is_a?(Mysql2::Error) && e.error_number == 1062 }
    allow(client).to receive(:connection_error_class).and_return(Mysql2::Error)
    allow(client).to receive(:primary_key).and_return("id")
    allow(client).to receive(:unique_columns).and_return([])

    # Mock count query
    allow(client).to receive(:query).with(/SELECT COUNT/).and_return([{ "count" => 1 }])

    # Mock progress bar
    allow(ProgressBar).to receive(:create).and_return(double("ProgressBar", increment: nil, finish: nil))

    config.table(:users) do |t|
      t.column :email, type: :email
    end
  end

  it "updates rows in the database" do
    allow(client).to receive(:query).with("SELECT * FROM users", stream: true, cache_rows: false).and_return([
      { "id" => 1, "email" => "test@example.com" },
    ])

    # Expect update with scrubbed value
    expect(client).to receive(:query).with(/UPDATE users SET email = 'escaped_.*' WHERE id = 1/)

    processor = described_class.new(config, db_config)
    processor.run
  end

  it "does not execute updates in dry-run mode" do
    allow(client).to receive(:query).with("SELECT * FROM users", stream: true, cache_rows: false).and_return([
      { "id" => 1, "email" => "test@example.com" },
    ])

    expect(client).not_to receive(:query).with(/UPDATE/)

    processor = described_class.new(config, db_config, dry_run: true)
    # Capture stdout to verify logging
    expect { processor.run }.to output(/\[DRY RUN\] UPDATE users SET email = 'escaped_.*' WHERE id = 1/).to_stdout
  end

  it "updates multiple columns in a single statement" do
    config.table(:users) do |t|
      t.column :email, type: :email
      t.column :name, type: :name
    end

    allow(client).to receive(:query).with("SELECT * FROM users", stream: true, cache_rows: false).and_return([
      { "id" => 1, "email" => "test@example.com", "name" => "Old Name" },
    ])

    # Expect single update with both columns
    expect(client).to receive(:query).with(/UPDATE users SET email = 'escaped_.*', name = 'escaped_.*' WHERE id = 1/)

    processor = described_class.new(config, db_config)
    processor.run
  end

  it "retries on collision (duplicate entry)" do
    allow(client).to receive(:query).with("SELECT * FROM users", stream: true, cache_rows: false).and_return([
      { "id" => 1, "email" => "test@example.com" },
    ])

    # Simulate failure on first call, success on second
    call_count = 0
    allow(client).to receive(:query).with(/UPDATE users SET email = 'escaped_.*' WHERE id = 1/) do
      call_count += 1
      if call_count == 1
        error = Mysql2::Error.new("Duplicate entry")
        # Stub error_number if it's the real Mysql2::Error class
        allow(error).to receive(:error_number).and_return(1062) if error.respond_to?(:error_number)
        # If it's our mock class, it might have set it via initialize if we passed it, but real class doesn't.
        # Our mock class initialize: def initialize(msg, error_number = nil)
        # So passing 2 args works for mock, but fails for real class?
        # Wait, if real class is used, new("msg", 1062) might raise ArgumentError!
        # But the error was Mysql2::Error: Duplicate entry. So it didn't raise ArgumentError.
        # So maybe real class accepts extra args?
        # Regardless, let's ensure error_number is set.
        if defined?(Mysql2::Error) && error.is_a?(Mysql2::Error)
          allow(error).to receive(:error_number).and_return(1062)
        end
        raise error
      else
        true
      end
    end

    processor = described_class.new(config, db_config)
    processor.run

    expect(call_count).to eq(2)
  end

  it "fails after max retries" do
    allow(client).to receive(:query).with("SELECT * FROM users", stream: true, cache_rows: false).and_return([
      { "id" => 1, "email" => "test@example.com" },
    ])

    # Always fail with duplicate entry
    allow(client).to receive(:query).with(/UPDATE users SET email = 'escaped_.*' WHERE id = 1/).and_raise(
      Mysql2::Error.new("Duplicate entry", 1062)
    )

    processor = described_class.new(config, db_config)

    # Should raise the error after retries
    expect { processor.run }.to raise_error(Mysql2::Error, "Duplicate entry")
  end

  it "raises other errors" do
    allow(client).to receive(:query).with("SELECT * FROM users", stream: true, cache_rows: false).and_return([
      { "id" => 1, "email" => "test@example.com" },
    ])

    allow(client).to receive(:query).with(/UPDATE users SET email = 'escaped_.*' WHERE id = 1/).and_raise(
      Mysql2::Error.new("Connection lost", 2013)
    )

    processor = described_class.new(config, db_config)
    expect { processor.run }.to raise_error(Mysql2::Error, "Connection lost")
  end

  it "skips update if configured columns are missing in the row" do
    # Row missing 'email' column
    allow(client).to receive(:query).with("SELECT * FROM users", stream: true, cache_rows: false).and_return([
      { "id" => 1, "other_col" => "val" },
    ])

    # Should NOT trigger update
    expect(client).not_to receive(:query).with(/UPDATE/)

    processor = described_class.new(config, db_config)
    processor.run
  end

  context "when mysql2 gem is missing" do
    before do
      allow(Scrub::DbAdapters).to receive(:connect).and_call_original
      allow_any_instance_of(Scrub::DbAdapters::Mysql).to receive(:require).with("mysql2").and_raise(LoadError)
    end

    it "raises a helpful error" do
      expect { described_class.new(config, db_config) }.to raise_error(LoadError, /The 'mysql2' gem is required/)
    end
  end

  it "raises generic errors" do
    allow(client).to receive(:query).with("SELECT * FROM users", stream: true, cache_rows: false).and_return([
      { "id" => 1, "email" => "test@example.com" },
    ])

    allow(client).to receive(:query).with(/UPDATE/).and_raise(StandardError.new("Something went wrong"))

    processor = described_class.new(config, db_config)
    expect { processor.run }.to raise_error(StandardError, "Something went wrong")
  end

  describe "connection management" do
    it "establishes two connections in live mode" do
      expect(Scrub::DbAdapters).to receive(:connect).twice.and_return(client)
      described_class.new(config, db_config, dry_run: false)
    end

    it "establishes one connection in dry-run mode" do
      expect(Scrub::DbAdapters).to receive(:connect).once.and_return(client)
      described_class.new(config, db_config, dry_run: true)
    end
  end

  it "handles errors in dry-run mode gracefully" do
    allow(client).to receive(:query).with("SELECT * FROM users", stream: true, cache_rows: false).and_return([
      { "id" => 1, "email" => "test@example.com" },
    ])

    # Force an error during processing
    allow_any_instance_of(Scrub::RowScrubber).to receive(:scrub).and_raise(StandardError.new("Scrub failed"))

    processor = described_class.new(config, db_config, dry_run: true)
    expect { processor.run }.to raise_error(StandardError, "Scrub failed")
  end

  describe "bloom filter usage" do
    before do
      allow(client).to receive(:query).with(/UPDATE/).and_return(nil)
    end

    it "initializes bloom filter when unique columns are present" do
      allow(client).to receive(:unique_columns).with("users").and_return(["email"])
      allow(client).to receive(:query).with("SELECT * FROM users", stream: true, cache_rows: false).and_return([
        { "id" => 1, "email" => "test@example.com" },
      ])

      expect(BloomFilter::Native).to receive(:new).and_call_original

      processor = described_class.new(config, db_config)
      processor.run
    end

    it "does not initialize bloom filter when no unique columns match" do
      allow(client).to receive(:unique_columns).with("users").and_return(["other_col"])
      allow(client).to receive(:query).with("SELECT * FROM users", stream: true, cache_rows: false).and_return([
        { "id" => 1, "email" => "test@example.com" },
      ])

      expect(BloomFilter::Native).not_to receive(:new)

      processor = described_class.new(config, db_config)
      processor.run
    end

    it "retries generation on bloom filter collision" do
      allow(client).to receive(:unique_columns).with("users").and_return(["email"])
      allow(client).to receive(:query).with("SELECT * FROM users", stream: true, cache_rows: false).and_return([
        { "id" => 1, "email" => "test@example.com" },
      ])
      allow(client).to receive(:query).with(/UPDATE/).and_return(nil)

      bloom_mock = instance_double(BloomFilter::Native)
      allow(BloomFilter::Native).to receive(:new).and_return(bloom_mock)

      # Simulate collision on first attempt (generate_fresh), success on second (mutate_original)
      expect(bloom_mock).to receive(:include?).with(/email:.*/).and_return(true, false)
      expect(bloom_mock).to receive(:insert).with(/email:.*/)

      processor = described_class.new(config, db_config)
      processor.run
    end
  end
end
