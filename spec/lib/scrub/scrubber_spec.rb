# frozen_string_literal: true

require "spec_helper"

RSpec.describe Scrub::Scrubber do
  let(:scrubber) { described_class.new }

  describe "#scrub" do
    context "when generate_fresh is not implemented" do
      it "raises NotImplementedError" do
        expect { scrubber.scrub("original") }.to raise_error(NotImplementedError)
      end
    end

    context "with a concrete implementation" do
      let(:concrete_class) do
        Class.new(Scrub::Scrubber) do
          def generate_fresh(original, _row)
            "fresh_#{original}"
          end
        end
      end
      let(:scrubber) { concrete_class.new }

      it "returns the generated value if valid" do
        expect(scrubber.scrub("original")).to eq("fresh_original")
      end

      it "accepts any value if no validator provided" do
        # Should return the first candidate (fresh)
        expect(scrubber.scrub("original", nil)).to eq("fresh_original")
      end

      it "uses the validator if provided" do
        # Should return the first candidate (fresh) because validator returns true
        expect(scrubber.scrub("original") { |v| true }).to eq("fresh_original")
      end

      it "falls back to mutation if generated value is invalid" do
        validator = proc { |val| val != "fresh_original" }
        # Mutation: "#{original}_#{rand}"
        result = scrubber.scrub("original", &validator)
        expect(result).to start_with("original_")
        expect(result).not_to eq("fresh_original")
      end

      it "falls back to masking if mutation is invalid" do
        validator = proc { |val| val != "fresh_original" && !val.start_with?("original_") }
        # Masking: "o***l"
        result = scrubber.scrub("original", &validator)
        expect(result).to eq("o******l")
      end

      it "returns nil if nothing is valid (should ideally not happen if masking is safe)" do
        validator = proc { false }
        expect(scrubber.scrub("original", &validator)).to be_nil
      end
    end
  end

  describe "#mask_original" do
    it "masks the value" do
      expect(scrubber.mask_original("secret", {})).to eq("s****t")
    end

    it "returns original if too short" do
      expect(scrubber.mask_original("a", {})).to eq("a")
    end

    it "returns nil if nil" do
      expect(scrubber.mask_original(nil, {})).to be_nil
    end
  end

  describe "#mutate_original" do
    it "appends a random number" do
      expect(scrubber.mutate_original("value", {})).to match(/value_\d{4}/)
    end
  end
end
