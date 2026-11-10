# frozen_string_literal: true

require "fileutils"
require "rexml/document"
require "rexml/formatters/default"

module LatexTesting
  class JUnitReport
    def self.write(filename, suites)
      document = REXML::Document.new
      document << REXML::XMLDecl.new("1.0", "UTF-8")
      root = document.add_element("testsuites")
      all_tests = suites.flat_map { |suite| suite.fetch(:tests) }
      root.add_attributes(
        "tests" => all_tests.length.to_s,
        "failures" => all_tests.count { |test| test.result == :failed }.to_s,
        "errors" => "0",
        "skipped" => "0"
      )

      suites.each do |suite|
        tests = suite.fetch(:tests)
        failures = tests.count { |test| test.result == :failed }
        suite_element = root.add_element(
          "testsuite",
          "name" => suite.fetch(:name).to_s,
          "tests" => tests.length.to_s,
          "failures" => failures.to_s,
          "errors" => "0",
          "skipped" => "0"
        )

        tests.each do |test|
          test_element = suite_element.add_element(
            "testcase",
            "classname" => suite.fetch(:name).to_s,
            "name" => test.name
          )
          next unless test.result == :failed

          message = test.failure_message.to_s
          failure = test_element.add_element("failure", "message" => message)
          failure.text = message
        end
      end

      FileUtils.mkdir_p(File.dirname(filename.to_s))
      File.open(filename, "w") do |file|
        REXML::Formatters::Default.new.write(document, file)
        file.write("\n")
      end
    end
  end
end
