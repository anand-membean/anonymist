# frozen_string_literal: true

module Scrub
  class Scrubber
    def initialize(options = {})
      @options = options
    end

    # The main entry point.
    # Returns the scrubbed value.
    #
    # @param original_value [String] The original PII.
    # @param row_context [Hash] The full row data (for dependencies).
    # @param validator [Proc] A predicate (val -> Boolean) to check uniqueness.
    def scrub(original_value, row_context = {}, &validator)
      # Functional pipeline: Try steps in order until one satisfies the validator
      candidates.lazy.map { |step| step.call(original_value, row_context) }
        .detect { |val| validator ? validator.call(val) : true }
    end

    private def candidates
      [
        method(:generate_fresh),   # 1. Try to generate a clean, fake value
        method(:mutate_original),  # 2. Fallback: Mutate the original (e.g. append numbers)
        method(:mask_original), # 3. Fallback: Mask it (e.g. ***@domain.com)
      ]
    end

    # Abstract: To be implemented by subclasses
    def generate_fresh(original_value, row_context)
      raise NotImplementedError
    end

    # Shared logic (can be overridden)
    def mutate_original(original_value, _row_context)
      "#{original_value}_#{rand(1000..9999)}"
    end

    def mask_original(original_value, _row_context)
      return original_value if original_value.nil? || original_value.length < 2
      "#{original_value[0]}#{'*' * (original_value.length - 2)}#{original_value[-1]}"
    end
  end
end
