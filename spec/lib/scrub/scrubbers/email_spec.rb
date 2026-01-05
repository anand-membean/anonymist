# frozen_string_literal: true

require "spec_helper"

RSpec.describe Scrub::Scrubbers::Email do
  let(:options) { {} }
  let(:scrubber) { described_class.new(options) }

  describe "#scrub" do
    it "generates a fresh email" do
      expect(scrubber.scrub("old@example.com")).to match(/@/)
      expect(scrubber.scrub("old@example.com")).not_to eq("old@example.com")
    end

    context "with domain option" do
      let(:options) { { domain: "custom.com" } }

      it "uses the custom domain" do
        expect(scrubber.scrub("old@example.com")).to end_with("@custom.com")
      end
    end

    context "with name_column option" do
      let(:options) { { name_column: "fullname" } }
      let(:row) { { "fullname" => "John Doe" } }

      it "uses the name from the row" do
        email = scrubber.scrub("old@example.com", row)
        expect(email).to include("john")
        expect(email).to include("doe")
      end

      it "ignores name if row is nil" do
        email = scrubber.scrub("old@example.com", nil)
        expect(email).to match(/@/)
      end

      it "ignores name if column missing in row" do
        email = scrubber.scrub("old@example.com", { "other" => "val" })
        expect(email).to match(/@/)
      end

      it "ignores name if column is nil in row" do
        email = scrubber.scrub("old@example.com", { "fullname" => nil })
        expect(email).to match(/@/)
      end
    end

    context "with preserve_domain option" do
      let(:options) { { preserve_domain: true } }

      it "preserves the original domain" do
        expect(scrubber.scrub("old@original.com")).to end_with("@original.com")
      end

      it "falls back to default if original has no domain" do
        expect(scrubber.scrub("invalid-email")).to match(/@/)
      end
    end

    context "fallback to masking" do
      it "masks the email user part" do
        # Reject generated and mutated values, accept masked value
        validator = proc { |val| val.include?("*") }

        # Masking: "o*d@example.com"
        result = scrubber.scrub("old@example.com", &validator)
        expect(result).to match(/\A.\*+.@example\.com\z/)
      end

      it "returns original if not an email" do
        # If it's not an email, mask_original returns it as is.
        expect(scrubber.mask_original("not-an-email", {})).to eq("not-an-email")
      end

      it "masks the user part correctly" do
        expect(scrubber.mask_original("user@example.com", {})).to eq("u**r@example.com")
      end

      it "handles short user parts by keeping them as is" do
        expect(scrubber.mask_original("a@example.com", {})).to eq("a@example.com")
      end
    end
  end
end
