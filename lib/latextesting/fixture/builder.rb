# frozen_string_literal: true

module LatexTesting
  class Fixture
    # Handles the compile and artifact lifecycle for a fixture.
    class Builder
      def initialize(**configuration)
        @name = configuration.fetch(:name)
        @file = configuration.fetch(:file)
        @input_dir = configuration.fetch(:input_dir)
        @output_dir = configuration.fetch(:output_dir)
        @output_pdf_path = configuration.fetch(:output_pdf_path)
        @output_log_path = File.join(File.dirname(@output_pdf_path), "#{@name}.log")
        @expect_compilation_failure = configuration.fetch(:expect_compilation_failure)
        @build = configuration.fetch(:build)
      end

      def build(temp_dir)
        source = source_path
        temp_log = temp_file(temp_dir, ".log")
        build_from_source(temp_dir, source, temp_log)
        nil
      rescue StandardError => e
        save_failure_log(temp_log) if temp_log
        "#{@file || @name}: #{e.message}"
      end

      private

      def build_from_source(temp_dir, source, temp_log)
        temp_pdf = temp_file(temp_dir, ".pdf")
        FileUtils.rm_f(File.join(@output_dir, "fixture.pdf"))
        FileUtils.rm_f(File.join(@output_dir, "fixture.log"))
        FileUtils.rm_f(@output_pdf_path)
        FileUtils.rm_f(@output_log_path)
        build_succeeded = @build.call(source, temp_dir)
        validate_build_result(build_succeeded)
        persist_build(build_succeeded, temp_pdf, temp_log)
      end

      def source_path
        raise "no .tex file given" unless @file

        source = Pathname.new(@input_dir).join(@file).to_s
        raise "#{@file} not found" unless File.file?(source)

        FileUtils.mkdir_p(File.dirname(@output_dir))
        source
      end

      def validate_build_result(build_succeeded)
        return unless build_succeeded == @expect_compilation_failure

        message = build_succeeded ? "Build passed unexpectedly" : "Build did not pass"
        raise message
      end

      def persist_build(build_succeeded, temp_pdf, temp_log)
        if build_succeeded
          raise "Build completed without producing a PDF" unless File.file?(temp_pdf)

          FileUtils.cp(temp_pdf, @output_pdf_path)
        else
          save_failure_log(temp_log)
        end
      end

      def save_failure_log(temp_log)
        log = if File.file?(temp_log)
                File.read(temp_log)
              else
                "Build failed for #{@file}"
              end
        File.write(@output_log_path, log)
      end

      def temp_file(temp_dir, extension)
        file = Pathname.new(@file)
        File.join(temp_dir, file.basename.sub_ext(extension))
      end
    end
  end
end
