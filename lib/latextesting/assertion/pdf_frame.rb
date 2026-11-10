# frozen_string_literal: true

module LatexTesting
  class Assertion
    class Execution
      class PDFExecution
        # An immutable rectangle recognized from stroked PDF paths.
        class Frame
          # Normalized color components that also retain their PDF color space.
          class Color < Array
            attr_reader :color_space

            def initialize(color_space, components)
              super(components)
              @color_space = color_space
              freeze
            end

            def components
              self
            end
          end

          SIDES = %i[left bottom right top].freeze

          attr_reader :color, :stroke_width, *SIDES

          def initialize(color:, stroke_width:, bounds:)
            @color = color
            @stroke_width = stroke_width
            SIDES.each { |side| instance_variable_set(:"@#{side}", bounds.fetch(side)) }
            freeze
          end

          def [](key)
            return public_send(key) if (SIDES + %i[color stroke_width width height]).include?(key)

            raise KeyError, "Unknown frame property: #{key.inspect}"
          end

          def width
            right - left
          end

          def height
            top - bottom
          end
        end
      end
    end
  end
end
