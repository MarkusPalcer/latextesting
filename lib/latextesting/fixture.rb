# frozen_string_literal: true

module LatexTesting
  # Compiles one LaTeX source once and runs its independently named tests.
  class Fixture
    attr_reader :name, :tests, :definition_file

    def initialize(name, output_dir:, input_dir:, definition_file:)
      @name = name.to_s
      @output_dir = output_dir
      @input_dir = input_dir
      @definition_file = definition_file
      @file = nil
      @expect_compilation_failure = false
      @tests = []
      @test_names = {}
      @output_pdf_path = File.join(File.dirname(@output_dir), "#{@name}.pdf")
    end

    def test(name, &block)
      raise "test defined without code block" unless block

      add_test(name, block: block)
    end

    def manual_test(message)
      add_test(message, manual: true)
    end

    def file(value)
      @file = value
    end

    def expect_compilation_failure
      @expect_compilation_failure = true
    end

    def requires_log(snippet)
      test("Log contains '#{snippet}'") do
        raise "Not found" unless log.include?(snippet)
      end
    end

    def execute(options = {}, tests: @tests, **run_options)
      options = options.merge(run_options)
      return true if tests.empty?

      puts "  #{@name}"
      Dir.mktmpdir("latex-testing-") { |temp_dir| execute_tests_in(temp_dir, tests, options) }

      tests.none? { |test| test.result == :failed }
    end

    private

    def add_test(name, block: nil, manual: false)
      name = name.to_s
      raise ArgumentError, "duplicate test name '#{name}' in fixture '#{@name}'" if @test_names.key?(name)

      test = Test.new(name, fixture: self, block: block, manual: manual)
      @test_names[name] = true
      @tests << test
      test
    end

    def execute_tests_in(temp_dir, tests, options)
      failure_message = build(temp_dir)
      return fail_tests(tests, failure_message) if failure_message

      execution = Assertion::Execution.new(
        temp_dir,
        @file,
        output_pdf_path: @output_pdf_path,
        user_interaction: options[:user_interaction]
      )
      tests.each { |test| test.execute(execution) }
    end

    def build(temp_dir)
      Builder.new(
        name: @name,
        file: @file,
        input_dir: @input_dir,
        output_dir: @output_dir,
        output_pdf_path: @output_pdf_path,
        expect_compilation_failure: @expect_compilation_failure,
        build: ->(source, directory) { build_raw(source, directory) }
      ).build(temp_dir)
    end

    def fail_tests(tests, message)
      tests.each { |test| test.fail(message) }
    end
  end
end
