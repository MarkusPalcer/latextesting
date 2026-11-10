# frozen_string_literal: true

module LatexTesting
  class Assertion
    class Execution
      class PDFExecution
        # Enumerable collection of extracted frames with an exact-one lookup.
        class FrameCollection
          include Enumerable

          def initialize(frames)
            @frames = frames.freeze
            freeze
          end

          def each(&block)
            return enum_for(__method__) unless block

            @frames.each(&block)
          end

          def single(&predicate)
            raise ArgumentError, "single requires a predicate block" unless predicate

            matches = select(&predicate)
            return matches.first if matches.length == 1

            raise "Expected exactly one matching frame, found none" if matches.empty?

            raise "Expected exactly one matching frame, found #{matches.length}"
          end
        end
      end
    end
  end
end
