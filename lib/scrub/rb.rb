# frozen_string_literal: true

require "zeitwerk"

Zeitwerk::Loader.new.then do |loader|
  loader.tag = "scrub-rb"
  loader.push_dir "#{__dir__}/.."
  loader.setup
end

module Scrub
  # Main namespace.
  module Rb
    def self.loader registry = Zeitwerk::Registry
        @loader ||= registry.loaders.find { |loader| loader.tag == "scrub-rb" }
  end

  end
end
