# frozen_string_literal: true

require "faker"

module Scrub
  module Scrubbers
    class Email < Scrubber
      def generate_fresh(original, row_context)
        email_options = {}

        if @options[:preserve_domain] && original.to_s.include?("@")
          email_options[:domain] = original.split("@").last
        elsif @options[:domain]
          email_options[:domain] = @options[:domain]
        end

        if @options[:name_column] && row_context && row_context[@options[:name_column]]
          email_options[:name] = row_context[@options[:name_column]]
        end

        ::Faker::Internet.email(**email_options)
      end

      # Custom fallback for emails to ensure they remain valid email format
      def mask_original(original, row_context)
        return original unless original.include?("@")

        user, domain = original.split("@", 2)
        masked_user = super(user, row_context)
        "#{masked_user}@#{domain}"
      end
    end
  end
end
