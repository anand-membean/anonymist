# frozen_string_literal: true

module Scrub
  class ColumnConfig
    attr_reader :name, :type, :options

    def initialize(name, type:, **options)
      @name = name.to_s
      @type = type.to_sym
      @options = options
    end

    def scrubber
      @scrubber ||= begin
        klass = case @type
                when :email
                  Scrubbers::Email
                when :name, :first_name, :last_name
                  Scrubbers::Name
                else
                  Scrubbers::Text
        end

        # Pass the type type as an option so the scrubber knows what to do (e.g. :first_name vs :last_name)
        klass.new(@options.merge(type: @type))
      end
    end

    def dependencies
      deps = []

      if @options[:depends_on]
        Array(@options[:depends_on]).each do |dep|
          deps << dep.to_s
        end
      end

      deps.uniq
    end
  end
end
