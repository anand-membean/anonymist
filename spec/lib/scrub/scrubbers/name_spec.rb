# frozen_string_literal: true

require "spec_helper"

RSpec.describe Scrub::Scrubbers::Name do
  let(:options) { {} }
  let(:scrubber) { described_class.new(options) }

  describe "#scrub" do
    it "generates a name" do
      expect(scrubber.scrub("Old Name")).not_to eq("Old Name")
    end

    context "with no type option" do
      let(:options) { {} }
      it "defaults to :name" do
        # Ensure it calls Faker::Name.name
        allow(Faker::Name).to receive(:name).and_call_original
        scrubber.scrub("Old")
        expect(Faker::Name).to have_received(:name)
      end
    end

    context "with type :first_name" do
      let(:options) { { type: :first_name } }
      it "generates a first name" do
        allow(Faker::Name).to receive(:first_name).and_call_original
        scrubber.scrub("Old")
        expect(Faker::Name).to have_received(:first_name)
      end
    end

    context "with type :last_name" do
      let(:options) { { type: :last_name } }
      it "generates a last name" do
        allow(Faker::Name).to receive(:last_name).and_call_original
        scrubber.scrub("Old")
        expect(Faker::Name).to have_received(:last_name)
      end
    end
  end
end
