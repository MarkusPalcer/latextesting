# frozen_string_literal: true

module LatexTesting
  class Assertion
    class Execution
      # Combines assertion helpers with a HexaPDF document's public API.
      class PDFExecution
        def initialize(execution, document)
          @execution = execution
          @document = document
          @pages = nil
        end

        def pages
          @pages ||= PageCollection.new(@document.pages)
        end

        def method_missing(name, *arguments, **keywords, &block)
          target = @execution.respond_to?(name) ? @execution : @document
          target.public_send(name, *arguments, **keywords, &block)
        end

        def respond_to_missing?(name, include_private = false)
          @execution.respond_to?(name, include_private) ||
            @document.respond_to?(name, include_private) ||
            super
        end
      end
    end
  end
end
