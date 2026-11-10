# frozen_string_literal: true

module LatexTesting
  class Assertion
    class Execution
      class PDFExecution
        # Delegates HexaPDF page methods and lazily exposes geometry assertions.
        class Page
          Boundary = Struct.new(:left, :bottom, :right, :top, keyword_init: true) do
            def initialize(**values)
              super
              freeze
            end

            def width
              right - left
            end

            def height
              top - bottom
            end
          end

          def initialize(page)
            @page = page
            @boundary = nil
            @frames = nil
          end

          def boundary
            @boundary ||= begin
              box = @page.box(:media)
              Boundary.new(left: box.left, bottom: box.bottom, right: box.right, top: box.top)
            end
          end

          def frames
            @frames ||= FrameCollection.new(extract_frames)
          end

          def convert_unit(value, target_unit)
            unless value.is_a?(Numeric) && target_unit.is_a?(Numeric)
              raise ArgumentError, "value and target unit must be numeric"
            end

            value * (@page[:UserUnit] || 1) * target_unit
          end

          def method_missing(name, *arguments, **keywords, &block)
            return super unless @page.respond_to?(name)

            @page.public_send(name, *arguments, **keywords, &block)
          end

          def respond_to_missing?(name, include_private = false)
            @page.respond_to?(name, include_private) || super
          end

          private

          def extract_frames
            require "hexapdf"
            require_relative "pdf_frame_processor"
            require_relative "pdf_frame_extractor"
            processor = FrameProcessor.new(@page.resources)
            HexaPDF::Content::Parser.parse(@page.contents, processor)
            FrameExtractor.new(processor.strokes).extract
          end
        end
      end
    end
  end
end
