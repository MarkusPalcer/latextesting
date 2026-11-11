# frozen_string_literal: true

module LatexTesting
  # Represents one named fact checked against a compiled fixture.
  class Test
    attr_reader :name, :fixture, :result, :failure_message

    def initialize(name, fixture:, block:, manual: false)
      @name = name.to_s
      @fixture = fixture
      @block = block
      @manual = manual
      @result = nil
      @failure_message = nil
    end

    def execute(execution)
      print "    #{@name} - "
      @result = nil
      @failure_message = nil
      report_result(execute_block(execution))
      true
    rescue RSpec::Expectations::ExpectationNotMetError, StandardError => e
      message = @manual ? e.message : "#{@name}: #{e.message}"
      fail(message, prefix: false)
    end

    def fail(message, prefix: true)
      print "    #{@name} - " if prefix
      @result = :failed
      @failure_message = message
      puts "#{RED}FAIL#{RESET}: #{message}"
      false
    end

    private

    def execute_block(execution)
      return execution.manual_test(@name) if @manual

      execution.instance_exec(&@block)
    end

    def report_result(result)
      case result
      when :manual_test_skipped
        print_result(YELLOW, "MANUAL TEST SKIPPED", :manual_test_skipped)
      when :manual_test_passed
        print_result(GREEN, "PASSED", :passed)
      else
        print_result(GREEN, "PASS", :passed)
      end
    end

    def print_result(color, message, result)
      @result = result
      puts "#{color}#{message}#{RESET}"
    end
  end
end
