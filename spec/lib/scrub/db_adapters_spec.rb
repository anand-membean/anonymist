# frozen_string_literal: true

require "spec_helper"
require "scrub/db_adapters"

RSpec.describe Scrub::DbAdapters do
  describe ".connect" do
    context "with mysql adapter" do
      let(:config) { { adapter: "mysql", host: "localhost" } }

      it "returns a Mysql adapter instance" do
        # Mock Mysql.new to avoid actual connection or require
        allow(Scrub::DbAdapters::Mysql).to receive(:new).with(config).and_return(double("MysqlAdapter"))
        expect(described_class.connect(config)).to be_truthy
      end
    end

    context "with mysql2 adapter string" do
      let(:config) { { adapter: "mysql2", host: "localhost" } }

      it "returns a Mysql adapter instance" do
        allow(Scrub::DbAdapters::Mysql).to receive(:new).with(config).and_return(double("MysqlAdapter"))
        expect(described_class.connect(config)).to be_truthy
      end
    end

    context "with unsupported adapter" do
      let(:config) { { adapter: "postgres" } }

      it "raises ArgumentError" do
        expect { described_class.connect(config) }.to raise_error(ArgumentError, /Unsupported database adapter: postgres/)
      end
    end
  end
end
