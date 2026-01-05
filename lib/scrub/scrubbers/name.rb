# frozen_string_literal: true

require "faker"

module Scrub
  module Scrubbers
    class Name < Scrubber
      def generate_fresh(_original, _row_context)
        type = @options[:type] || :name
        case type
        when :first_name
          ::Faker::Name.first_name
        when :last_name
          ::Faker::Name.last_name
        else
          ::Faker::Name.name
        end
      end
    end
  end
end
