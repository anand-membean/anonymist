# frozen_string_literal: true

require "spec_helper"

RSpec.describe Scrub do
  describe ".configuration" do
    it "returns a Config object" do
      expect(described_class.configuration).to be_a(Scrub::Config)
    end

    it "memoizes the configuration" do
      expect(described_class.configuration).to equal(described_class.configuration)
    end
  end

  describe ".configure" do
    it "yields the configuration" do
      expect { |b| described_class.configure(&b) }.to yield_with_args(Scrub::Config)
    end
  end

  describe ".scrub_dump" do
    let(:input) { double("Input") }
    let(:output) { double("Output") }
    let(:config) { instance_double(Scrub::Config) }
    let(:processor) { instance_double(Scrub::Processors::Dump) }

    before do
      allow(Scrub::Processors::Dump).to receive(:new).and_return(processor)
      allow(processor).to receive(:process)
    end

    it "delegates to Processors::Dump" do
      described_class.scrub_dump(input, output, config:)

      expect(Scrub::Processors::Dump).to have_received(:new).with(config)
      expect(processor).to have_received(:process).with(input, output)
    end

    it "uses default configuration if none provided" do
      described_class.scrub_dump(input, output)

      expect(Scrub::Processors::Dump).to have_received(:new).with(described_class.configuration)
    end
  end

  describe ".scrub_live" do
    let(:db_config) { { host: "localhost" } }
    let(:config) { instance_double(Scrub::Config) }
    let(:processor) { instance_double(Scrub::Processors::Live) }

    before do
      allow(Scrub::Processors::Live).to receive(:new).and_return(processor)
      allow(processor).to receive(:run)
    end

    it "delegates to Processors::Live" do
      described_class.scrub_live(db_config, config:)

      expect(Scrub::Processors::Live).to have_received(:new).with(config, db_config)
      expect(processor).to have_received(:run)
    end

    it "uses default configuration if none provided" do
      described_class.scrub_live(db_config)

      expect(Scrub::Processors::Live).to have_received(:new).with(described_class.configuration, db_config)
    end
  end
end
