# frozen_string_literal: true

require "spec_helper"

RSpec.describe Scrub::TableConfig do
  let(:config) { described_class.new("users") }

  describe "#column" do
    it "adds a column config" do
      config.column("email", :email)
      expect(config.columns["email"]).to be_a(Scrub::ColumnConfig)
    end
  end

  describe "#sorted_columns" do
    it "returns columns in dependency order" do
      config.column("email", :email, name_column: "fullname", depends_on: "fullname")
      config.column("fullname", :name)

      sorted = config.sorted_columns
      expect(sorted.map(&:name)).to eq(["fullname", "email"])
    end

    it "raises error on circular dependency" do
      # A depends on B, B depends on A
      # We need to mock dependencies since we don't have a type that depends on another arbitrary column easily
      # But we can use :email type with name_column

      # This is tricky because we can't easily create a circular dependency with just :email type unless we have another type that depends on email.
      # But we can mock the dependencies method on ColumnConfig instances.

      col_a = Scrub::ColumnConfig.new("a", type: :text)
      col_b = Scrub::ColumnConfig.new("b", type: :text)

      allow(col_a).to receive(:dependencies).and_return(["b"])
      allow(col_b).to receive(:dependencies).and_return(["a"])

      config.instance_variable_get(:@columns)["a"] = col_a
      config.instance_variable_get(:@columns)["b"] = col_b

      expect { config.sorted_columns }.to raise_error(/Circular dependency detected/)
    end

    it "handles self dependency" do
      col_a = Scrub::ColumnConfig.new("a", type: :text)
      allow(col_a).to receive(:dependencies).and_return(["a"])
      config.instance_variable_get(:@columns)["a"] = col_a

      expect { config.sorted_columns }.to raise_error(/Circular dependency detected/)
    end
  end
end
