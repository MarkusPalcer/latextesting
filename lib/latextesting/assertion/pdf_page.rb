# frozen_string_literal: true

module LatexTesting
  class Assertion
    class Execution
      class PDFExecution
        # Delegates HexaPDF page methods and lazily exposes geometry assertions.
        class Page
          Boundary = LatexTesting::Boundary

          def initialize(page)
            @page = page
          end

          def boundary
            @boundary ||= begin
              box = box(:media)
              Boundary.new(left: box.left, bottom: box.bottom, right: box.right, top: box.top)
            end
          end

          def frames
            @frames ||= FrameCollection.new(extract_frames)
          end

          def text_lines
            @text_lines ||= begin
              require "hexapdf"
              require_relative "pdf_text_line_extractor"
              TextLineExtractor.new(@page).extract
            end
          end

          def convert_unit(value, target_unit)
            validate_conversion_arguments(value, target_unit)
            return convert_boundary(value, target_unit) if value.is_a?(Boundary)

            value * (self[:UserUnit] || 1) * target_unit
          end

          def method_missing(name, *arguments, **keywords, &block)
            super unless delegated_method?(name, false)

            @page.public_send(name, *arguments, **keywords, &block)
          end

          def respond_to_missing?(name, include_private)
            delegated_method?(name, include_private)
          end

          private

          def validate_conversion_arguments(value, target_unit)
            return if (value.is_a?(Numeric) || value.is_a?(Boundary)) && target_unit.is_a?(Numeric)

            raise ArgumentError, "value must be numeric or a Boundary and target unit must be numeric"
          end

          def convert_boundary(boundary, target_unit)
            factor = (self[:UserUnit] || 1) * target_unit
            Boundary.new(
              left: boundary.left * factor,
              top: boundary.top * factor,
              right: boundary.right * factor,
              bottom: boundary.bottom * factor
            )
          end

          def delegated_method?(name, include_private)
            @page.respond_to?(name, include_private)
          end

          def extract_frames
            require "hexapdf"
            require_relative "pdf_frame_processor"
            require_relative "pdf_frame_extractor"
            processor = FrameProcessor.new(resources)
            HexaPDF::Content::Parser.parse(contents, processor)
            FrameExtractor.new(processor.strokes).extract
          end
        end
      end
    end
  end
end
