# frozen_string_literal: true

require "zeitwerk"

Zeitwerk::Loader.new.then do |loader|
  loader.tag = "scrub-rb"
  loader.push_dir "#{__dir__}/"
  loader.setup
end

module Scrub
  # Main namespace.
  def self.loader(registry = Zeitwerk::Registry)
    return @loader if @loader

    registry.loaders.each do |loader|
      return @loader = loader if loader.tag == "scrub-rb"
    end
    nil
  end

  class Error < StandardError; end

  class << self
    attr_writer :configuration
    attr_reader :config
  end

  def self.configuration
    @configuration ||= Config.new
  end

  # def self.configure
  #   yield(configuration)
  # end

  def self.configure(&block)
    @config = Config.new
    @config.instance_eval(&block)
  end

  # Scrub a database dump stream.
  #
  # @param input_stream [IO] Input stream (e.g., File or $stdin)
  # @param output_stream [IO] Output stream (e.g., File or $stdout)
  # @param config [Scrub::Config] Configuration object (defaults to global config)
  def self.scrub_dump(input_stream, output_stream, config: configuration)
    Processors::Dump.new(config).process(input_stream, output_stream)
  end

  # Scrub a live database.
  #
  # @param db_config [Hash] Database connection configuration (host, user, password, db)
  # @param config [Scrub::Config] Configuration object (defaults to global config)
  def self.scrub_live(db_config, config: configuration)
    Processors::Live.new(config, db_config).run
  end

  def self.scrub_anand(connection)
    Scrub::Runner.new(connection).run
  end
end
