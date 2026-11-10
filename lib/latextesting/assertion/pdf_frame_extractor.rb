# frozen_string_literal: true

module LatexTesting
  class Assertion
    class Execution
      class PDFExecution
        # Groups parsed strokes into uniquely identifiable rectangular frames.
        class FrameExtractor
          TOLERANCE = FrameProcessor::TOLERANCE

          def initialize(strokes)
            @strokes = strokes
          end

          def extract
            grouped_strokes.flat_map do |group|
              extract_group(group)
            end.sort_by(&:first).map(&:last)
          end

          private

          def grouped_strokes
            @strokes.group_by do |stroke|
              [stroke.color_space, stroke.color.map { |component| component.round(3) }, stroke.width.round(3)]
            end.values
          end

          def extract_group(strokes)
            strokes.each { |stroke| validate_line(stroke) }
            partitions = FramePartitioner.new(strokes).find(2)
            raise "Unsupported frame geometry: strokes do not form complete rectangular frames" if partitions.empty?
            raise "Ambiguous frame geometry: strokes can be grouped into multiple frame sets" if partitions.length > 1

            partitions.first.map { |frame| [frame.map(&:index).min, build_frame(frame)] }
          end

          def validate_line(stroke)
            first, second = stroke.points
            horizontal = (first[1] - second[1]).abs <= TOLERANCE
            vertical = (first[0] - second[0]).abs <= TOLERANCE
            raise "Unsupported frame geometry: strokes must be non-zero axis-aligned lines" unless horizontal ^ vertical
            raise "Unsupported frame geometry: stroke width must be positive" unless stroke.width.positive?
          end

          def build_frame(strokes)
            half_width = strokes.sum(&:width) / strokes.length / 2
            Frame.new(
              color: frame_color(strokes),
              stroke_width: half_width * 2,
              bounds: frame_bounds(strokes, half_width)
            )
          end

          def frame_color(strokes)
            Frame::Color.new(strokes.first.color_space, strokes.first.color)
          end

          def frame_bounds(strokes, half_width)
            horizontal, vertical = FrameGeometry.partition(strokes)
            x_edges = vertical.map { |stroke| FrameGeometry.midpoint(stroke, :x) }
            y_edges = horizontal.map { |stroke| FrameGeometry.midpoint(stroke, :y) }
            { left: x_edges.min - half_width, bottom: y_edges.min - half_width,
              right: x_edges.max + half_width, top: y_edges.max + half_width }
          end
        end

        # Finds exact, non-overlapping frame partitions among strokes.
        class FramePartitioner
          def initialize(strokes)
            @strokes = strokes
          end

          def find(limit)
            return [] if limit.zero?
            return [[]] if @strokes.empty?

            solutions = []
            candidates_for_first.each do |candidate|
              add_partition(candidate, limit, solutions)
              break if solutions.length >= limit
            end
            solutions
          end

          private

          def candidates_for_first
            first = @strokes.first
            FrameGeometry.candidates(@strokes).select do |candidate|
              candidate.any? { |stroke| stroke.index == first.index }
            end
          end

          def add_partition(candidate, limit, solutions)
            remaining = @strokes.reject { |stroke| candidate.any? { |part| part.index == stroke.index } }
            tails = self.class.new(remaining).find(limit - solutions.length)
            solutions.concat(tails.map { |tail| [candidate, *tail] })
          end
        end

        # Applies the supported rectangle constraints to candidate strokes.
        class FrameGeometry
          TOLERANCE = FrameProcessor::TOLERANCE

          def self.partition(strokes)
            strokes.partition { |stroke| horizontal?(stroke) }
          end

          def self.midpoint(stroke, axis)
            coordinate = axis == :x ? 0 : 1
            stroke.points.sum { |point| point[coordinate] } / 2.0
          end

          def self.candidates(strokes)
            horizontal, vertical = partition(strokes)
            horizontal.combination(2).flat_map do |horizontal_pair|
              vertical.combination(2).filter_map do |vertical_pair|
                frame = horizontal_pair + vertical_pair
                frame if rectangular?(frame)
              end
            end
          end

          def self.horizontal?(stroke)
            (stroke.points[0][1] - stroke.points[1][1]).abs <= TOLERANCE
          end

          private_class_method :horizontal?

          def self.rectangular?(strokes)
            horizontal, vertical = partition(strokes)
            return false unless rectangle_edges?(horizontal, vertical, strokes)

            half_width = strokes.sum(&:width) / strokes.length / 2
            edges_form_rectangle?(horizontal, vertical, half_width)
          end

          def self.edges_form_rectangle?(horizontal, vertical, half_width)
            x_edges = vertical.map { |stroke| midpoint(stroke, :x) }.sort
            y_edges = horizontal.map { |stroke| midpoint(stroke, :y) }.sort
            return false unless distinct_edges?(x_edges) && distinct_edges?(y_edges)

            horizontal_match?(horizontal, x_edges, half_width) &&
              vertical_match?(vertical, y_edges)
          end

          def self.rectangle_edges?(horizontal, vertical, strokes)
            horizontal.length == 2 && vertical.length == 2 && consistent_width?(strokes)
          end

          def self.consistent_width?(strokes)
            strokes.map(&:width).max - strokes.map(&:width).min <= TOLERANCE
          end

          def self.distinct_edges?(edges)
            (edges[1] - edges[0]).abs > TOLERANCE
          end

          def self.horizontal_match?(strokes, x_edges, half_width)
            expected = [x_edges[0] - half_width, x_edges[1] + half_width]
            strokes.all? { |stroke| endpoints_match?(stroke, :x, expected) }
          end

          def self.vertical_match?(strokes, y_edges)
            strokes.all? { |stroke| endpoints_match?(stroke, :y, y_edges) }
          end

          def self.endpoints_match?(stroke, axis, expected)
            coordinate = axis == :x ? 0 : 1
            actual = stroke.points.map { |point| point[coordinate] }.sort
            actual.zip(expected).all? { |first, second| (first - second).abs <= TOLERANCE }
          end
        end
      end
    end
  end
end
