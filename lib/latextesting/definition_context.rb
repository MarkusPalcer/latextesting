# frozen_string_literal: true

module LatexTesting
  # Evaluates declaration files while resolving fixture paths relative to them.
  class DefinitionContext
    attr_reader :filename, :fixtures

    def initialize(filename, fixtures)
      @filename = File.expand_path(filename)
      @fixtures = fixtures
    end

    def fixture(name, &block)
      raise "fixture defined without data" unless block

      fixture = build_fixture(name)
      LatexTesting.register_fixture(fixture)
      @fixtures << fixture
      fixture.instance_eval(&block)
      raise ArgumentError, "fixture '#{fixture.name}' has no tests" if fixture.tests.empty?

      fixture
    end

    private

    def build_fixture(name)
      base_dir = output_base
      Fixture.new(
        name,
        output_dir: File.join(base_dir, name.to_s),
        input_dir: File.dirname(@filename),
        definition_file: @filename
      )
    end

    def output_base
      relative_path = Pathname(@filename).relative_path_from(PROJECT_ROOT)

      relative_path = relative_path.sub(/\.rb\z/, "")
      File.join(OUT_DIR, relative_path)
    end
  end
end
