# frozen_string_literal: true

require "fileutils"
require "rexml/document"
require "rexml/formatters/default"

module LatexTesting
  # Writes individual fixture tests using JUnit's required XML structure.
  class JUnitReport
    def self.write(filename, fixtures)
      write_document(filename, build_document(fixtures))
    end

    def self.build_document(fixtures)
      document = REXML::Document.new
      document << REXML::XMLDecl.new(nil, "UTF-8")
      root = document.add_element("testsuites")
      all_tests = fixtures.flat_map { |fixture| fixture.fetch(:tests) }
      root.add_attributes(summary_attributes(all_tests))

      fixtures.each { |fixture| add_fixture(root, fixture) }
      document
    end

    def self.write_document(filename, document)
      FileUtils.mkdir_p(File.dirname(filename))
      File.open(filename, "w") do |file|
        REXML::Formatters::Default.new.write(document, file)
        file.write("\n")
      end
    end

    def self.add_fixture(root, fixture)
      tests = fixture.fetch(:tests)
      fixture_element = root.add_element("testsuite", fixture_attributes(fixture, tests))

      tests.each { |test| add_test_case(fixture_element, fixture.fetch(:name), test) }
    end

    def self.summary_attributes(tests)
      {
        "tests" => tests.length.to_s,
        "failures" => tests.count { |test| test.result == :failed }.to_s,
        "errors" => "0",
        "skipped" => "0"
      }
    end

    def self.fixture_attributes(fixture, tests)
      {
        "name" => fixture.fetch(:name).to_s,
        "tests" => tests.length.to_s,
        "failures" => tests.count { |test| test.result == :failed }.to_s,
        "errors" => "0",
        "skipped" => "0"
      }
    end

    def self.add_test_case(fixture_element, fixture_name, test)
      test_element = fixture_element.add_element(
        "testcase",
        "classname" => fixture_name,
        "name" => test.name
      )
      return unless test.result == :failed

      message = test.failure_message.to_s
      failure = test_element.add_element("failure", "message" => message)
      failure.text = message
    end
  end
end
