# frozen_string_literal: true

module LatexTesting
  class Assertion
    class Execution
      class PDFExecution
        # Collects individual stroked line paths while tracking PDF graphics state.
        class FrameProcessor < HexaPDF::Content::Processor
          Stroke = Struct.new(:index, :color_space, :color, :width, :points, keyword_init: true)
          TOLERANCE = 0.001

          attr_reader :strokes

          def initialize(resources)
            @strokes = []
            @path = []
            @unsupported_path = false
            super
          end

          def move_to(x_coordinate, y_coordinate)
            @unsupported_path = true unless @path.empty?
            @path = [transform_point(x_coordinate, y_coordinate)]
          end

          def line_to(x_coordinate, y_coordinate)
            @unsupported_path = true if @path.empty?
            @path << transform_point(x_coordinate, y_coordinate)
          end

          def curve_to(*, **)
            @unsupported_path = true
          end

          alias curve_to_no_first_control_point curve_to
          alias curve_to_no_second_control_point curve_to

          def close_subpath
            @unsupported_path = true
          end

          def append_rectangle(*)
            @unsupported_path = true
          end

          def stroke_path
            capture_stroke
            reset_path
          end

          def close_and_stroke_path
            @unsupported_path = true
            capture_stroke
            reset_path
          end

          def fill_and_stroke_path_non_zero
            @unsupported_path = true
            capture_stroke
            reset_path
          end

          alias fill_and_stroke_path_even_odd fill_and_stroke_path_non_zero
          alias close_fill_and_stroke_path_non_zero fill_and_stroke_path_non_zero
          alias close_fill_and_stroke_path_even_odd fill_and_stroke_path_non_zero

          def end_path
            reset_path
          end

          def fill_path_non_zero
            reset_path
          end

          alias fill_path_even_odd fill_path_non_zero
          alias clip_path_non_zero fill_path_non_zero
          alias clip_path_even_odd fill_path_non_zero

          private

          def capture_stroke
            raise "Unsupported frame path: expected one straight line segment" if @unsupported_path || @path.length != 2

            validate_transform
            validate_line_cap
            @strokes << stroke_value
          end

          def stroke_value
            color = graphics_state.stroke_color
            Stroke.new(
              index: @strokes.length,
              color_space: color.color_space.family,
              color: color.components.dup.freeze,
              width: graphics_state.line_width,
              points: @path.map(&:freeze).freeze
            ).freeze
          end

          def transform_point(x_coordinate, y_coordinate)
            @unsupported_path = true unless supported_transform?
            graphics_state.ctm.evaluate(x_coordinate, y_coordinate)
          end

          def validate_transform
            return if supported_transform?

            raise "Unsupported frame path: scaled or rotated transformations are not supported"
          end

          def supported_transform?
            graphics_state.ctm.to_a[0..3].zip([1, 0, 0, 1]).all? do |actual, expected|
              (actual - expected).abs <= TOLERANCE
            end
          end

          def validate_line_cap
            return if graphics_state.line_cap_style.value.zero?

            raise "Unsupported frame path: only butt line caps are supported"
          end

          def reset_path
            @path = []
            @unsupported_path = false
          end
        end
      end
    end
  end
end
