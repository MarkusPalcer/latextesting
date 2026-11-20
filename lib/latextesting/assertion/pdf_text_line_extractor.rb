# frozen_string_literal: true

module LatexTesting
  class Assertion
    class Execution
      class PDFExecution
        TextLine = Struct.new(:text, :boundary, keyword_init: true)

        # Groups HexaPDF text runs into lines with MediaBox-relative boundaries.
        class TextLineExtractor
          def initialize(page)
            @page = page
          end

          def extract
            runs = collect_runs
            return [].freeze if runs.empty?

            build_lines(runs)
          end

          private

          def collect_runs
            processor = HexaPDF::Content::SmartTextExtractor::TextRunProcessor.new
            @page.process_contents(processor)
            processor.text_runs.reject { |run| run.string.empty? }
          end

          def build_lines(runs)
            median_glyph_width = median_glyph_width(runs)
            media_box = @page.box(:media)
            group_runs(runs).map do |line_runs|
              build_line(line_runs, median_glyph_width, media_box)
            end.freeze
          end

          def median_glyph_width(runs)
            widths = runs.map { |run| run.width / run.string.length.to_f }.sort
            median(widths)
          end

          def group_runs(runs)
            tolerance = line_tolerance(runs)
            lines = []
            runs.sort_by { |run| [-run.baseline, run.left] }.each do |run|
              append_run(lines, run, tolerance)
            end

            lines.map { |line| line.sort_by(&:left) }
          end

          def append_run(lines, run, tolerance)
            line = lines.last
            if line.nil? || !same_line?(line, run, tolerance)
              lines << [run]
            else
              line << run
            end
          end

          def same_line?(line, run, tolerance)
            (median(line.map(&:baseline).sort) - run.baseline).abs <= tolerance
          end

          def line_tolerance(runs)
            median_height = [median(runs.map(&:height).sort), 1].max
            [median_height * 0.4, 2].max
          end

          def build_line(line_runs, median_glyph_width, media_box)
            TextLine.new(
              text: reconstruct_text(line_runs, median_glyph_width).freeze,
              boundary: line_boundary(line_runs, media_box)
            ).freeze
          end

          def line_boundary(line_runs, media_box)
            x_bounds = horizontal_bounds(line_runs)
            y_bounds = vertical_bounds(line_runs)
            boundary_from_bounds(x_bounds, y_bounds, media_box)
          end

          def horizontal_bounds(line_runs)
            [line_runs.map(&:left).min, line_runs.map(&:right).max]
          end

          def vertical_bounds(line_runs)
            [line_runs.map(&:bottom).min, line_runs.map(&:top).max]
          end

          def boundary_from_bounds(x_bounds, y_bounds, media_box)
            Boundary.new(
              left: x_bounds.first - media_box.left,
              top: media_box.top - y_bounds.last,
              right: x_bounds.last - media_box.left,
              bottom: media_box.top - y_bounds.first
            )
          end

          def reconstruct_text(line_runs, median_glyph_width)
            line_runs.each_with_index.each_with_object(+"") do |(run, index), text|
              text << " " if index.positive? && word_gap?(line_runs, index, median_glyph_width)
              text << run.string
            end
          end

          def word_gap?(line_runs, index, median_glyph_width)
            previous = line_runs[index - 1]
            current = line_runs[index]
            current.left - previous.right > median_glyph_width * 0.5 &&
              previous.string[-1] != " " && current.string[0] != " "
          end

          def median(sorted_values)
            middle = sorted_values.length / 2
            return sorted_values[middle] if sorted_values.length.odd?

            (sorted_values[middle - 1] + sorted_values[middle]) / 2.0
          end
        end
      end
    end
  end
end
