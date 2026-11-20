# frozen_string_literal: true

module LatexTesting
  # Adds a containment variant of RSpec's be_within matcher for Boundary values.
  module BoundaryMatchers
    # Checks whether a boundary is inclusively contained by another boundary.
    class BoundaryMatcher
      def initialize(containing_boundary)
        @containing_boundary = containing_boundary
      end

      def matches?(actual)
        @actual = actual
        actual.is_a?(Boundary) &&
          actual.left >= @containing_boundary.left &&
          actual.top >= @containing_boundary.top &&
          actual.right <= @containing_boundary.right &&
          actual.bottom <= @containing_boundary.bottom
      end

      def failure_message
        message = "expected #{@actual.inspect} to be within #{@containing_boundary.inspect}"
        return message unless @actual.is_a?(Boundary)

        separation = separation_details
        return "actual is completely outside expected: #{separation.join(", ")}; #{message}" unless separation.empty?

        "actual extends beyond expected: #{overrun_details.join(", ")}; #{message}"
      end

      def failure_message_when_negated
        "expected #{@actual.inspect} not to be within #{@containing_boundary.inspect}"
      end

      private

      def separation_details
        comparisons([
                      ["left of expected", :right, :left, :<],
                      ["right of expected", :left, :right, :>],
                      ["above expected", :bottom, :top, :<],
                      ["below expected", :top, :bottom, :>]
                    ])
      end

      def overrun_details
        comparisons([
                      ["left", :left, :left, :<],
                      ["top", :top, :top, :<],
                      ["right", :right, :right, :>],
                      ["bottom", :bottom, :bottom, :>]
                    ])
      end

      def comparisons(edges)
        edges.filter_map do |label, actual_edge, expected_edge, operator|
          actual_value = @actual.public_send(actual_edge)
          expected_value = @containing_boundary.public_send(expected_edge)
          next unless actual_value.public_send(operator, expected_value)

          "#{label} (actual.#{actual_edge}=#{actual_value} #{operator} expected.#{expected_edge}=#{expected_value})"
        end
      end
    end

    def be_within(value)
      return super unless value.is_a?(Boundary)

      BoundaryMatcher.new(value)
    end
  end
end
