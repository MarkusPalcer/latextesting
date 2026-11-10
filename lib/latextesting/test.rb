# frozen_string_literal: true

module LatexTesting
  class Test
    attr_reader :name

    def initialize(name, output_dir:, input_dir:)
      @name = name.to_s
      @output_dir = output_dir
      @input_dir = input_dir
      @file = nil
      @expect_compilation_failure = false
      @assertions = []
      @output_pdf_path = File.join(@output_dir, "#{@name}.pdf")
    end

    def assert(name = nil, &block)
      raise "assertion called without code block" unless block_given?

      @assertions << Assertion.new(@file, name, block)
    end

    def user_assert(message)
      assert("User assertion") { user_assert(message) }
    end

    def file(value)
      @file = value
    end

    def expect_compilation_failure
      @expect_compilation_failure = true
    end

    def requires_log(snippet)
      assert "Log contains '#{snippet}'" do
        fail "Not found" unless log.include? snippet
      end
    end

    def execute(options = {})
      print "    #{@name} - "
      begin
        raise "no .tex file given" unless @file

        file = Pathname.new(@input_dir).join(@file).to_s
        raise "#{@file} not found" unless File.file?(file)

        skipped_manual_assertions = 0
        manual_tests_passed = false
        Dir.mktmpdir("latex-testing-") do |temp_dir|
          result = run(temp_dir)
          raise "Build did not pass" if !result && !@expect_compilation_failure
          raise "Build passed unexpectedly" if result && @expect_compilation_failure

          FileUtils.cp(temp_file(temp_dir, ".pdf"), @output_pdf_path) if result

          execution = Assertion::Execution.new(
            temp_dir,
            @file,
            output_pdf_path: @output_pdf_path,
            user_interaction: options[:user_interaction]
          )
          @assertions.each do |assertion|
            result = assertion.execute(temp_dir, execution: execution)
            skipped_manual_assertions += 1 if result == :manual_test_skipped
            manual_tests_passed ||= result == :manual_test_passed
          end
        end

        if skipped_manual_assertions.positive?
          puts "#{YELLOW}#{skipped_manual_assertions} MANUAL TESTS SKIPPED#{RESET}"
        elsif manual_tests_passed
          puts "#{GREEN}PASSED#{RESET}"
        else
          puts "#{GREEN}PASS#{RESET}"
        end
        true
      rescue StandardError => e
        puts "#{RED}FAIL#{RESET}: #{e.message}"
        false
      end
    end

    private

    def temp_file(temp_dir, extension)
      file = Pathname.new(@file)
      File.join(temp_dir, "#{file.basename.sub_ext(extension)}")
    end

    def run(temp_dir)
      file = Pathname.new(@input_dir).join(@file).to_s
      temp_dir = Pathname.new(temp_dir)
      FileUtils.mkdir_p(@output_dir)

      temp_pdf = temp_file(temp_dir, ".pdf")
      temp_log = temp_file(temp_dir, ".log")

      begin
        raise "Build failed" unless build_raw file, temp_dir
        raise "Build completed without producing a PDF" unless File.file?(temp_pdf)

        true
      rescue StandardError => e
        log = if File.file?(temp_log)
                File.read(temp_log)
              else
                "#{e.class}: #{e.message}\n#{e.backtrace&.join("\n")}"
              end

        File.write(File.join(@output_dir, "#{@name}.log"), log)
        false
      end
    end
  end
end
