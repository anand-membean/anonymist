# frozen_string_literal: true

require "spec_helper"

RSpec.describe Scrub::Scrubbers::Text do
  let(:options) { {} }
  let(:scrubber) { described_class.new(options) }

  describe "#scrub" do
    it "generates a word by default" do
      allow(Faker::Lorem).to receive(:word).and_call_original
      scrubber.scrub("Old Text")
      expect(Faker::Lorem).to have_received(:word)
    end

    context "with type :username" do
      let(:options) { { type: :username } }
      it "generates a username" do
        allow(Faker::Internet).to receive(:username).and_call_original
        scrubber.scrub("olduser")
        expect(Faker::Internet).to have_received(:username)
      end
    end
  end
end
