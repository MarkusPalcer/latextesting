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

          def [](*arguments)
            wrap(@pages[*arguments])
          end

          def each(&block)
            return enum_for(__method__) unless block

            @pages.each { |page| block.call(wrap(page)) }
            self
          end

          def length
            @pages.length
          end
          alias size length

          def method_missing(name, *arguments, **keywords, &block)
            return super unless @pages.respond_to?(name)

            wrap(@pages.public_send(name, *arguments, **keywords, &block))
          end

          def respond_to_missing?(name, include_private = false)
            @pages.respond_to?(name, include_private) || super
          end

          private

          def wrap(page)
            case page
            when Array
              page.map { |item| wrap(item) }
            when nil
              nil
            else
              @page_proxies[page] ||= Page.new(page)
            end
          end
        end
      end
    end
  end
end
