# frozen_string_literal: true

module LatexTesting
  class Assertion
    class Execution
      def initialize(temp_dir, file, output_pdf_path: nil, user_interaction: false)
        @temp_dir = temp_dir
        @file = file
        @output_pdf_path = output_pdf_path
        @user_interaction = user_interaction
        @log = nil
        @pdf_execution = nil
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

      def user_assert(message)
        path = pdf_path
        return :manual_test_skipped unless @user_interaction

        puts message
        puts "PDF: #{path}"

        loop do
          print "Does this assertion pass? [yes/no] "
          response = $stdin.gets
          raise "No response received for user assertion" if response.nil?
          puts

          case response.strip.downcase
          when "yes", "y"
            return :manual_test_passed
          when "no", "n"
            raise "User assertion rejected: #{message}"
          end
        end
      end

      def generated_pdf(&block)
        raise "generated_pdf called without code block" unless block_given?

        require "hexapdf"
        @pdf_execution ||= PDFExecution.new(self, HexaPDF::Document.open(pdf_path))
        @pdf_execution.instance_exec(&block)
      end

      def fail(message)
        raise message
      end

      private

      def temp_file(extension)
        file = Pathname.new(@file)
        File.join(@temp_dir, "#{file.basename.sub_ext(extension)}")
      end
    end
  end
end
