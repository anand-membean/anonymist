# frozen_string_literal: true

require "spec_helper"

RSpec.describe Scrub::DbAdapters::Mysql do
  let(:config) { { host: "localhost", username: "root" } }
  let(:client) { instance_double(Mysql2::Client) }

  before do
    allow(Mysql2::Client).to receive(:new).with(config).and_return(client)
  end

  subject { described_class.new(config) }

  describe "#initialize" do
    it "initializes Mysql2::Client" do
      expect(subject).to be_a(described_class)
    end

    context "when mysql2 load fails" do
      before do
        # Simulate LoadError during initialization
        allow(Mysql2::Client).to receive(:new).and_raise(LoadError)
      end

      it "raises LoadError with helpful message" do
        expect { subject }.to raise_error(LoadError) { |e|
          expect(e.message).to include("mysql2")
        }
      end
    end
  end

  describe "#query" do
    it "delegates to client" do
      expect(client).to receive(:query).with("SELECT 1", stream: true)
      subject.query("SELECT 1", stream: true)
    end
  end

  describe "#escape" do
    it "delegates to client" do
      expect(client).to receive(:escape).with("foo").and_return("foo")
      subject.escape("foo")
    end
  end

  describe "#connection_error_class" do
    it "returns Mysql2::Error" do
      expect(subject.connection_error_class).to eq(Mysql2::Error)
    end
  end

  describe "#duplicate_entry_error?" do
    let(:error) { Mysql2::Error.new("Duplicate entry") }

    it "returns true for error 1062" do
      allow(error).to receive(:error_number).and_return(1062)
      expect(subject.duplicate_entry_error?(error)).to be true
    end

    it "returns false for other errors" do
      allow(error).to receive(:error_number).and_return(1234)
      expect(subject.duplicate_entry_error?(error)).to be false
    end

    it "returns false for non-Mysql2 errors" do
      expect(subject.duplicate_entry_error?(StandardError.new)).to be false
    end
  end

  describe "#primary_key" do
    it "returns the column name if found" do
      result = [{ "COLUMN_NAME" => "pk_id" }]
      allow(client).to receive(:escape).with("users").and_return("users")
      expect(client).to receive(:query).with(/SELECT COLUMN_NAME/).and_return(result)
      expect(subject.primary_key("users")).to eq("pk_id")
    end

    it "returns 'id' if not found" do
      result = []
      allow(client).to receive(:escape).with("users").and_return("users")
      expect(client).to receive(:query).with(/SELECT COLUMN_NAME/).and_return(result)
      expect(subject.primary_key("users")).to eq("id")
    end

    it "returns 'id' if column name is nil" do
      result = [{ "COLUMN_NAME" => nil }]
      allow(client).to receive(:escape).with("users").and_return("users")
      expect(client).to receive(:query).with(/SELECT COLUMN_NAME/).and_return(result)
      expect(subject.primary_key("users")).to eq("id")
    end
  end

  describe "#unique_columns" do
    it "returns unique columns" do
      result = [
        { "COLUMN_NAME" => "email" },
        { "COLUMN_NAME" => "username" },
        { "COLUMN_NAME" => "email" }, # Duplicate to test uniq
      ]
      allow(client).to receive(:escape).with("users").and_return("users")
      expect(client).to receive(:query).with(/SELECT COLUMN_NAME.*STATISTICS/m).and_return(result)
      expect(subject.unique_columns("users")).to eq(["email", "username"])
    end
  end
end
