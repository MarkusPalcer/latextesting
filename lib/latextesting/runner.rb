# frozen_string_literal: true

module LatexTesting
  @files = {}

  class << self
    def parse_file(filename)
      filename = File.expand_path(filename)
      return @files[filename] if @files.key?(filename)

      test_file = TestFile.new(filename)
      @files[filename] = test_file

      source = File.read(filename)
      test_file.instance_eval(source, filename, 1)

      test_file
    rescue StandardError
      @files.delete(filename) if filename
      raise
    end

    def scan(base_dir)
      base_dir = base_dir.to_s
      patterns = %w[
        **/*tests.rb
        **/*test.rb
        **/test.rb
        **/tests.rb
      ]

      files = patterns.flat_map do |pattern|
        Dir.glob(File.join(base_dir, pattern))
      end

      files.uniq.sort.flat_map do |filename|
        parse_file(filename).suites
      end
    end

    def run(options = nil, suite: nil, test: nil, **run_options)
      options = (options || {}).merge(run_options)
      if suite && test && !suite.tests.include?(test)
        raise ArgumentError, "test does not belong to the selected suite"
      end

      report_suites = if test
                        [{ name: suite&.name || "LatexTesting", tests: [test] }]
                      elsif suite
                        [{ name: suite.name, tests: suite.tests }]
                      else
                        @files.each_value.flat_map do |test_file|
                          test_file.suites.map do |test_suite|
                            { name: test_suite.name, tests: test_suite.tests }
                          end
                        end
                      end

      result =
        if test
          test.execute(options)
        elsif suite
          suite.execute(options)
        else
          @files.each_value do |test_file|
            test_file.execute(options)
          end
        end

      JUnitReport.write(options[:junit_report], report_suites) if options[:junit_report]
      result
    end
  end
end
