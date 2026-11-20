# frozen_string_literal: true

module LatexTesting
  Boundary = Struct.new(:left, :bottom, :right, :top, keyword_init: true) do
    def initialize(**values)
      width = values.delete(:width)
      height = values.delete(:height)
      values = with_width(values, width)
      values = with_height(values, height)
      super(**values)
      freeze
    end

    def width
      (right - left).abs
    end

    def height
      (top - bottom).abs
    end

    private

    def with_width(values, width)
      return values unless width
      return values.merge(right: values[:left] + width) if values.key?(:left)
      return values.merge(left: values[:right] - width) if values.key?(:right)

      values
    end

    def with_height(values, height)
      return values unless height
      return values.merge(bottom: values[:top] + height) if values.key?(:top)
      return values.merge(top: values[:bottom] - height) if values.key?(:bottom)

      values
    end
  end
end
