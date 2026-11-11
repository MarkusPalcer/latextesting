# frozen_string_literal: true

module LatexTesting
  class Assertion
    class Execution
      class PDFExecution
        # Enumerable wrapper that returns stable proxies for HexaPDF pages.
        class PageCollection
          include Enumerable

          def initialize(pages)
            @pages = pages
            @page_proxies = {}.compare_by_identity
          end

          def each(&block)
            return enum_for unless block

            @pages.each { |page| block.call(wrap(page)) }
            self
          end

          def method_missing(name, *arguments, **keywords, &block)
            super unless delegated_method?(name, false)

            wrap(@pages.public_send(name, *arguments, **keywords, &block))
          end

          def respond_to_missing?(name, include_private)
            delegated_method?(name, include_private)
          end

          private

          def delegated_method?(name, include_private)
            @pages.respond_to?(name, include_private)
          end

          def wrap(page)
            case page
            when Array
              page.map { |item| wrap(item) }
            else
              return page unless page.respond_to?(:box)

              @page_proxies[page] ||= Page.new(page)
            end
          end
        end
      end
    end
  end
end
