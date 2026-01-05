# frozen_string_literal: true

require "spec_helper"

RSpec.describe Scrub::ColumnConfig do
  describe "#scrubber" do
    it "returns Email scrubber for :email type" do
      config = described_class.new("email", type: :email)
      expect(config.scrubber).to be_a(Scrub::Scrubbers::Email)
    end

    it "returns Name scrubber for :name type" do
      config = described_class.new("name", type: :name)
      expect(config.scrubber).to be_a(Scrub::Scrubbers::Name)
    end

    it "returns Name scrubber for :first_name type" do
      config = described_class.new("first_name", type: :first_name)
      expect(config.scrubber).to be_a(Scrub::Scrubbers::Name)
    end

    it "returns Name scrubber for :last_name type" do
      config = described_class.new("last_name", type: :last_name)
      expect(config.scrubber).to be_a(Scrub::Scrubbers::Name)
    end

    it "returns Text scrubber for unknown type" do
      config = described_class.new("username", type: :username)
      expect(config.scrubber).to be_a(Scrub::Scrubbers::Text)
    end

    it "memoizes the scrubber" do
      config = described_class.new("email", type: :email)
      expect(config.scrubber).to equal(config.scrubber)
    end
  end

  describe "#dependencies" do
    it "returns empty array by default" do
      config = described_class.new("email", type: :email)
      expect(config.dependencies).to be_empty
    end

    it "returns depends_on if present" do
      config = described_class.new("custom", type: :custom, depends_on: "other_col")
      expect(config.dependencies).to eq(["other_col"])
    end

    it "returns multiple dependencies if depends_on is an array" do
      config = described_class.new("custom", type: :custom, depends_on: ["col1", "col2"])
      expect(config.dependencies).to contain_exactly("col1", "col2")
    end
  end
end
