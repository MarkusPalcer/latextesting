# frozen_string_literal: true

module LatexTesting
  class TestSuite
    attr_reader :name, :tests

    def initialize(name, output_dir:, input_dir:)
      @name = name.to_s
      @output_dir = output_dir
      @input_dir = input_dir
      @tests = []
    end

    def test(name, &block)
      raise "test defined without data" unless block_given?

      test = Test.new(
        name,
        output_dir: File.join(@output_dir),
        input_dir: @input_dir
      )

      test.instance_eval(&block) if block
      @tests << test
      test
    end

    def execute(options = {})
      return if @tests.empty?

      puts "  #{@name}"
      @tests.each { |test| test.execute(options) }
    end
  end
end
