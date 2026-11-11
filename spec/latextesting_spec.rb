# frozen_string_literal: true

require "rexml/document"

RSpec.describe LatexTesting do
  before do
    described_class.instance_variable_set(:@parsed_files, {})
    described_class.instance_variable_set(:@fixtures, {})
  end

  it "has a version number" do
    expect(LatexTesting::VERSION).not_to be nil
  end

  it "loads fixture and test classes without file or suite model classes" do
    expect(described_class::DefinitionContext).to be_a(Class)
    expect(described_class::Fixture).to be_a(Class)
    expect(described_class::Test).to be_a(Class)
    expect(described_class.const_defined?(:TestFile, false)).to be(false)
    expect(described_class.const_defined?(:TestSuite, false)).to be(false)
  end

  it "discovers fixtures across definition files without adding a file-level suite" do
    Dir.mktmpdir do |directory|
      File.write(File.join(directory, "fixture.tex"), "")
      File.write(File.join(directory, "one_tests.rb"), <<~RUBY)
        fixture "One" do
          file "fixture.tex"
          test "First fact" do
          end
        end
      RUBY
      File.write(File.join(directory, "two_tests.rb"), <<~RUBY)
        fixture "Two" do
          file "fixture.tex"
          test "Second fact" do
          end
        end
      RUBY

      fixtures = described_class.scan(directory)

      expect(fixtures.map(&:name)).to eq(%w[One Two])
      expect(fixtures.map { |fixture| fixture.tests.map(&:name) })
        .to eq([["First fact"], ["Second fact"]])
    end
  end

  it "rejects fixture names duplicated across definition files" do
    Dir.mktmpdir do |directory|
      File.write(File.join(directory, "one_tests.rb"), <<~RUBY)
        fixture "Duplicate" do
          file "one.tex"
          test("First") {}
        end
      RUBY
      File.write(File.join(directory, "two_tests.rb"), <<~RUBY)
        fixture "Duplicate" do
          file "two.tex"
          test("Second") {}
        end
      RUBY

      expect { described_class.scan(directory) }
        .to raise_error(ArgumentError, /duplicate fixture name 'Duplicate'/)
    end
  end

  it "rejects duplicate test names within a fixture" do
    Dir.mktmpdir do |directory|
      filename = File.join(directory, "tests.rb")
      File.write(filename, <<~RUBY)
        fixture "Sample" do
          file "fixture.tex"
          test("Same fact") {}
          manual_test "Same fact"
        end
      RUBY

      expect { described_class.parse_file(filename) }
        .to raise_error(ArgumentError, /duplicate test name 'Same fact'/)
    end
  end

  it "runs only the selected fixture or selected test" do
    Dir.mktmpdir do |directory|
      first = create_fixture(directory, "First")
      selected_test = first.test("Selected") {}
      first.test("Other") {}
      second = create_fixture(directory, "Second")
      second.test("Second test") {}

      expect(first).to receive(:execute).with({ out_folder: "out" }, tests: first.tests)
      expect(second).not_to receive(:execute)
      described_class.run({ out_folder: "out" }, fixture: first)

      expect(first).to receive(:execute).with({ out_folder: "out" }, tests: [selected_test])
      expect(second).not_to receive(:execute)
      described_class.run({ out_folder: "out" }, test: selected_test)
    end
  end

  it "rejects a test outside the selected fixture" do
    Dir.mktmpdir do |directory|
      fixture = create_fixture(directory, "Fixture")
      test = fixture.test("First") {}
      other_fixture = create_fixture(directory, "Other")

      expect do
        described_class.run(fixture: other_fixture, test: test)
      end.to raise_error(ArgumentError, "test does not belong to the selected fixture")
    end
  end

  it "rejects the removed suite selector explicitly" do
    expect { described_class.run(suite: Object.new) }
      .to raise_error(ArgumentError, "suite selection has been removed; use fixture")
  end

  it "writes individual fixture tests to JUnit and continues after a failure" do
    Dir.mktmpdir do |directory|
      fixture = create_fixture(directory, "Suite & <group>")
      fixture.manual_test("The title is visible")
      fixture.test("Failure") { raise("actual & <text>") }
      fixture.test("After failure") { log }
      report = File.join(directory, "reports", "testresults.xml")

      expect { described_class.run({ junit_report: report }, fixture: fixture) }
        .to output(/MANUAL TEST SKIPPED.*Failure - .*FAIL.*Failure: actual.*After failure - .*PASS/m).to_stdout

      document = REXML::Document.new(File.read(report))
      fixture_element = document.elements["testsuites/testsuite"]
      test_cases = fixture_element.get_elements("testcase")
      failure = test_cases[1].elements["failure"]

      expect(fixture_element.attributes["tests"]).to eq("3")
      expect(fixture_element.attributes["failures"]).to eq("1")
      expect(fixture_element.attributes["name"]).to eq("Suite & <group>")
      expect(document.root.attributes["tests"]).to eq("3")
      expect(test_cases.map { |test_case| test_case.attributes["name"] })
        .to eq(["The title is visible", "Failure", "After failure"])
      expect(test_cases.first.elements["skipped"]).to be_nil
      expect(failure.attributes["message"]).to eq("Failure: actual & <text>")
      expect(failure.text).to eq("Failure: actual & <text>")
      expect(fixture.tests.last.result).to eq(:passed)
    end
  end

  it "reports only a selected test" do
    Dir.mktmpdir do |directory|
      fixture = create_fixture(directory, "Fixture")
      selected_test = fixture.test("Selected") { log }
      fixture.test("Other") { log }
      report = File.join(directory, "testresults.xml")

      expect { described_class.run({ junit_report: report }, test: selected_test) }
        .to output(/Selected.*PASS/m).to_stdout

      document = REXML::Document.new(File.read(report))
      test_cases = document.get_elements("testsuites/testsuite/testcase")
      expect(test_cases.map { |test_case| test_case.attributes["name"] }).to eq(["Selected"])
    end
  end

  it "marks every test in a fixture failed when the build fails" do
    Dir.mktmpdir do |directory|
      fixture = create_fixture(directory, "Build failure")
      fixture.test("First") {}
      fixture.test("Second") {}
      allow(fixture).to receive(:build_raw).and_return(false)

      expect { expect(fixture.execute).to be(false) }
        .to output(/First - .*FAIL.*Build did not pass.*Second - .*FAIL.*Build did not pass/m)
        .to_stdout
      expect(fixture.tests.map(&:result)).to eq(%i[failed failed])
    end
  end

  it "runs named log tests after an expected compilation failure" do
    Dir.mktmpdir do |directory|
      fixture = create_fixture(directory, "Expected failure")
      fixture.expect_compilation_failure
      fixture.requires_log("expected diagnostic")
      fixture.define_singleton_method(:build_raw) do |_source, temp_dir|
        File.write(File.join(temp_dir, "fixture.log"), "expected diagnostic")
        false
      end

      expect { expect(fixture.execute).to be(true) }
        .to output(/Log contains 'expected diagnostic'.*PASS/m).to_stdout
      expect(fixture.tests.first.result).to eq(:passed)
    end
  end

  it "fails all fixture tests when compilation succeeds unexpectedly" do
    Dir.mktmpdir do |directory|
      fixture = create_fixture(directory, "Unexpected success")
      fixture.expect_compilation_failure
      fixture.test("First") {}
      fixture.test("Second") {}

      expect { expect(fixture.execute).to be(false) }
        .to output(/First - .*FAIL.*Build passed unexpectedly.*Second - .*FAIL.*Build passed unexpectedly/m)
        .to_stdout
      expect(fixture.tests.map(&:result)).to eq(%i[failed failed])
    end
  end

  it "does not reuse a previous PDF after an expected failed build" do
    Dir.mktmpdir do |directory|
      fixture = create_fixture(directory, "Stale PDF")
      fixture.manual_test("The output PDF exists")
      legacy_output_dir = File.join(directory, "Stale PDF")
      FileUtils.mkdir_p(legacy_output_dir)
      File.write(File.join(legacy_output_dir, "fixture.pdf"), "old pdf")
      File.write(File.join(legacy_output_dir, "fixture.log"), "old log")

      expect { expect(fixture.execute).to be(true) }
        .to output(/MANUAL TEST SKIPPED/).to_stdout
      expect(File.file?(File.join(directory, "Stale PDF.pdf"))).to be(true)
      expect(File.file?(File.join(legacy_output_dir, "fixture.pdf"))).to be(false)
      expect(File.file?(File.join(legacy_output_dir, "fixture.log"))).to be(false)

      fixture.expect_compilation_failure
      allow(fixture).to receive(:build_raw) do |_source, temp_dir|
        File.write(File.join(temp_dir, "fixture.log"), "expected failure")
        false
      end

      expect { expect(fixture.execute).to be(false) }
        .to output(/No PDF file produced by LaTeX build/).to_stdout
      expect(File.file?(File.join(directory, "Stale PDF.pdf"))).to be(false)
      expect(File.read(File.join(directory, "Stale PDF.log"))).to eq("expected failure")
    end
  end

  it "writes the named PDF beside the fixture output directory" do
    Dir.mktmpdir do |directory|
      fixture = create_fixture(directory, "Named output")
      fixture.test("The PDF path uses the fixture name") do
        expect(File.basename(pdf_path)).to eq("Named output.pdf")
      end

      expect { expect(fixture.execute).to be(true) }
        .to output(/The PDF path uses the fixture name.*PASS/m).to_stdout
      expect(File.file?(File.join(directory, "Named output.pdf"))).to be(true)
      expect(File.directory?(File.join(directory, "Named output"))).to be(false)
    end
  end

  it "shares the cached log and PDF execution across named tests" do
    Dir.mktmpdir do |directory|
      fixture = create_fixture(directory, "Cache check")
      fixture.test("First") do
        log
        generated_pdf.pages.count
      end
      fixture.test("Second") do
        log
        generated_pdf.pages.count
      end

      document_class = Class.new
      document_class.define_singleton_method(:open) { |_path| Struct.new(:pages).new([]) }
      hexa_pdf = Module.new
      hexa_pdf.const_set(:Document, document_class)
      stub_const("HexaPDF", hexa_pdf)
      allow_any_instance_of(LatexTesting::Assertion::Execution)
        .to receive(:require).with("hexapdf")
      expect(document_class).to receive(:open).once.and_call_original
      expect(fixture).to receive(:build_raw).once.and_call_original
      expect(File).to receive(:read)
        .with(a_string_matching(/fixture\.log\z/)).once.and_call_original

      expect { expect(fixture.execute).to be(true) }
        .to output(/First - .*PASS.*Second - .*PASS/m).to_stdout
    end
  end

  it "runs manual tests interactively and fails when the user rejects one" do
    Dir.mktmpdir do |directory|
      fixture = create_fixture(directory, "Manual")
      fixture.manual_test("The title is visible")
      allow($stdin).to receive(:gets).and_return("no\n")

      expect do
        expect(fixture.execute(user_interaction: true)).to be(false)
      end.to output(
        /The title is visible - PDF: .*Manual\.pdf.*Does this test pass\?.*FAIL.*Manual test rejected/m
      ).to_stdout
    end
  end

  def create_fixture(directory, name)
    File.write(File.join(directory, "fixture.tex"), "")
    fixture = LatexTesting::Fixture.new(
      name,
      output_dir: File.join(directory, name),
      input_dir: directory,
      definition_file: File.join(directory, "tests.rb")
    )
    fixture.file("fixture.tex")
    fixture.define_singleton_method(:build_raw) do |_source, temp_dir|
      File.write(File.join(temp_dir, "fixture.pdf"), "pdf")
      File.write(File.join(temp_dir, "fixture.log"), "log")
      true
    end
    fixture
  end
end

RSpec.describe LatexTesting::Test do
  it "marks a skipped manual test as a passing result and requires a PDF" do
    Dir.mktmpdir do |directory|
      File.write(File.join(directory, "fixture.tex"), "")
      fixture = LatexTesting::Fixture.new(
        "Manual",
        output_dir: File.join(directory, "Manual"),
        input_dir: directory,
        definition_file: File.join(directory, "tests.rb")
      )
      fixture.file("fixture.tex")
      test = fixture.manual_test("The title is visible")
      fixture.define_singleton_method(:build_raw) do |_source, temp_dir|
        File.write(File.join(temp_dir, "fixture.pdf"), "pdf")
        File.write(File.join(temp_dir, "fixture.log"), "log")
        true
      end

      expect { expect(fixture.execute).to be(true) }
        .to output(/The title is visible.*MANUAL TEST SKIPPED/m).to_stdout
      expect(test.result).to eq(:manual_test_skipped)
    end
  end
end
