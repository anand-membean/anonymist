# frozen_string_literal: true

require "faker"

module Scrub
  module Scrubbers
    class Text < Scrubber
      def generate_fresh(_original, _row_context)
        type = @options[:type]
        case type
        when :username
          ::Faker::Internet.username
        else
          ::Faker::Lorem.word
        end
      end
    end
  end
end
