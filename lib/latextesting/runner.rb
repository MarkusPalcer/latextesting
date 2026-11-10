# frozen_string_literal: true

# Registers fixture definitions and executes selected tests.
module LatexTesting
  DEFINITION_FILE_PATTERNS = %w[
    **/*tests.rb
    **/*test.rb
    **/test.rb
    **/tests.rb
  ].freeze

  @parsed_files = {}
  @fixtures = {}

  class << self
    def parse_file(filename)
      filename = File.expand_path(filename)
      return @parsed_files[filename] if @parsed_files.key?(filename)

      parse_new_file(filename)
    end

    def register_fixture(fixture)
      if @fixtures.key?(fixture.name)
        existing = @fixtures.fetch(fixture.name)
        message = "duplicate fixture name '#{fixture.name}' in #{fixture.definition_file}"
        raise ArgumentError, "#{message} (already defined in #{existing.definition_file})"
      end

      @fixtures[fixture.name] = fixture
    end

    def scan(base_dir)
      definition_files(base_dir).flat_map { |filename| parse_file(filename) }
    end

    def run(options = nil, fixture: nil, test: nil, **run_options)
      options = (options || {}).merge(run_options)
      raise ArgumentError, "suite selection has been removed; use fixture" if options.key?(:suite)

      validate_selection(fixture, test)

      selected_fixtures = select_fixtures(fixture, test)
      selected_fixtures.each do |selected|
        selected.execute(options, tests: tests_for(selected, test))
      end

      write_report(options, selected_fixtures, test)
      nil
    end

    private

    def parse_new_file(filename)
      fixtures = []
      @parsed_files[filename] = fixtures

      source = File.read(filename)
      DefinitionContext.new(filename, fixtures).instance_eval(source, filename, 1)

      fixtures
    rescue StandardError
      rollback_parse(filename, fixtures)
      raise
    end

    def rollback_parse(filename, fixtures)
      fixtures&.each { |fixture| @fixtures.delete(fixture.name) }
      @parsed_files.delete(filename)
    end

    def definition_files(base_dir)
      DEFINITION_FILE_PATTERNS.flat_map do |pattern|
        Dir.glob(File.join(base_dir.to_s, pattern))
      end.uniq.sort
    end

    def validate_selection(fixture, test)
      return unless fixture && test && !fixture.tests.include?(test)

      raise ArgumentError, "test does not belong to the selected fixture"
    end

    def select_fixtures(fixture, test)
      return [test.fixture] if test
      return [fixture] if fixture

      @fixtures.values
    end

    def tests_for(fixture, test)
      return [test] if test

      fixture.tests
    end

    def report_fixtures(fixtures, test)
      fixtures.filter_map do |fixture|
        tests = tests_for(fixture, test)
        { name: fixture.name, tests: tests } unless tests.empty?
      end
    end

    def write_report(options, fixtures, test)
      filename = options[:junit_report]
      return unless filename

      JUnitReport.write(filename, report_fixtures(fixtures, test))
    end
  end
end
