# frozen_string_literal: true

require "rspec/expectations"

module LatexTesting
  class Assertion
    # Shares log and PDF access across the tests of one compiled fixture.
    class Execution
      include RSpec::Matchers

      def initialize(temp_dir, file, output_pdf_path: nil, user_interaction: false)
        @temp_dir = temp_dir
        @file = file
        @output_pdf_path = output_pdf_path
        @user_interaction = user_interaction
      end

      def log
        return @log unless @log.nil?

        temp_log = temp_file(".log")
        raise "No log file produced by LaTeX build" unless File.file?(temp_log)

        @log = File.read(temp_log)
      end

      def pdf_path
        path = @output_pdf_path || temp_file(".pdf")
        raise "No PDF file produced by LaTeX build" unless File.file?(path)

        path
      end

      def manual_test(message)
        path = pdf_path
        return :manual_test_skipped unless @user_interaction

        puts "PDF: #{path}"
        prompt_manual_test(message)
      end

      private

      def prompt_manual_test(message)
        loop do
          print "Does this test pass? [yes/no] "
          response = $stdin.gets
          raise "No response received for manual test" if response.nil?

          puts

          return manual_test_result(response, message) if manual_test_answer?(response)
        end
      end

      def manual_test_answer?(response)
        %w[yes y no n].include?(response.strip.downcase)
      end

      def manual_test_result(response, message)
        case response.strip.downcase
        when "yes", "y"
          :manual_test_passed
        when "no", "n"
          raise "Manual test rejected: #{message}"
        end
      end

      public

      def generated_pdf
        @generated_pdf ||= begin
          require "hexapdf"
          PDFExecution.new(self, HexaPDF::Document.open(pdf_path))
        end
      end

      private

      def temp_file(extension)
        file = Pathname.new(@file)
        File.join(@temp_dir, file.basename.sub_ext(extension))
      end
    end
  end
end
