# frozen_string_literal: true

module LatexTesting
  class TestFile
    attr_reader :filename

    def initialize(filename)
      @filename = File.expand_path(filename)
      @suites = {}
      @file_suite = TestSuite.new(
        File.basename(@filename, ".rb"),
        output_dir: output_base,
        input_dir: File.dirname(@filename)
      )
    end

    def testsuite(name, &block)
      raise "test suite defined without data" unless block_given?

      suite = @suites[name.to_s] ||= TestSuite.new(
        name,
        output_dir: File.join(output_base, name.to_s),
        input_dir: File.dirname(@filename)
      )

      suite.instance_eval(&block) if block
      suite
    end

    def test(name, &block)
      @file_suite.test(name, &block)
    end

    def suites
      ([@file_suite] + @suites.values).select { |suite| !suite.tests.empty? }
    end

    def execute(options = {})
      puts @filename
      @file_suite.execute(options)
      @suites.each_value { |suite| suite.execute(options) }
    end

    private

    def output_base
      relative_path = Pathname.new(@filename)
        .relative_path_from(PROJECT_ROOT)
        .to_s

      relative_path = relative_path.sub(/\.rb\z/, "")
      File.join(OUT_DIR, relative_path)
    end
  end
end
