# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength, Metrics/MethodLength, Metrics/ParameterLists -- mutation scenarios keep related behavioral assertions together.

require "latextesting"
require "hexapdf"
require "latextesting/assertion/pdf_frame_processor"
require "latextesting/assertion/pdf_frame_extractor"

module MutationCoverageSpecHelpers
  FRAME_PROCESSOR =
    LatexTesting::Assertion::Execution::PDFExecution::FrameProcessor

  def create_buildable_fixture(directory, name: "Fixture", file: "fixture.tex")
    source = File.join(directory, file)
    FileUtils.mkdir_p(File.dirname(source))
    File.write(source, "")

    fixture = LatexTesting::Fixture.new(
      name,
      output_dir: File.join(directory, "out", name),
      input_dir: directory,
      definition_file: File.join(directory, "tests.rb")
    )
    fixture.file(file)
    fixture.define_singleton_method(:build_raw) do |_source_path, temp_dir|
      basename = File.basename(file, File.extname(file))
      File.write(File.join(temp_dir, "#{basename}.pdf"), "pdf")
      File.write(File.join(temp_dir, "#{basename}.log"), "build log")
      true
    end
    fixture
  end

  def frame_stroke(index, points, color: [0.75, 0, 0], width: 2)
    FRAME_PROCESSOR::Stroke.new(
      index: index,
      color_space: :DeviceRGB,
      color: color,
      width: width,
      points: points
    )
  end

  def rectangle_strokes(left: 10, bottom: 20, right: 90, top: 100, width: 2, color: [0.75, 0, 0])
    half_width = width / 2.0
    [
      [[left - half_width, bottom], [right + half_width, bottom]],
      [[right, bottom], [right, top]],
      [[right + half_width, top], [left - half_width, top]],
      [[left, top], [left, bottom]]
    ].each_with_index.map { |points, index| frame_stroke(index, points, color: color, width: width) }
  end
end

RSpec.describe LatexTesting::Test, mutant_expression: ["LatexTesting::Test*"] do
  it "executes its block, reports a pass, and clears an earlier failure" do
    executions = 0
    should_fail = true
    execution = Object.new
    execution.define_singleton_method(:execution_check) { :checked }
    test = described_class.new("Title", fixture: Object.new, block: lambda {
      raise "failure" if should_fail

      raise "wrong execution context" unless execution_check == :checked

      executions += 1
    })

    expect { expect(test.execute(execution)).to be(false) }
      .to output("    Title - #{LatexTesting::RED}FAIL#{LatexTesting::RESET}: Title: failure\n").to_stdout
    expect(test.result).to eq(:failed)
    expect(test.failure_message).to eq("Title: failure")

    should_fail = false
    expect { expect(test.execute(execution)).to be(true) }
      .to output("    Title - #{LatexTesting::GREEN}PASS#{LatexTesting::RESET}\n").to_stdout
    expect(test.result).to eq(:passed)
    expect(test.failure_message).to be_nil
    expect(executions).to eq(1)
  end

  it "delegates manual tests and records skipped and accepted results" do
    skipped_test = described_class.new("Skipped", fixture: Object.new, block: nil, manual: true)
    skipped_execution = double(manual_test: :manual_test_skipped)
    expect(skipped_execution).to receive(:manual_test).with("Skipped").and_return(:manual_test_skipped)
    expect { skipped_test.execute(skipped_execution) }
      .to output("    Skipped - #{LatexTesting::YELLOW}MANUAL TEST SKIPPED#{LatexTesting::RESET}\n").to_stdout
    expect(skipped_test.result).to eq(:manual_test_skipped)

    accepted_test = described_class.new("Accepted", fixture: Object.new, block: nil, manual: true)
    accepted_execution = double(manual_test: :manual_test_passed)
    expect(accepted_execution).to receive(:manual_test).with("Accepted").and_return(:manual_test_passed)
    expect { accepted_test.execute(accepted_execution) }
      .to output("    Accepted - #{LatexTesting::GREEN}PASSED#{LatexTesting::RESET}\n").to_stdout
    expect(accepted_test.result).to eq(:passed)
  end

  it "reports manual failures without duplicating the test name" do
    test = described_class.new("Rejected", fixture: Object.new, block: nil, manual: true)
    execution = double(manual_test: nil)
    allow(execution).to receive(:manual_test).with("Rejected").and_raise("Manual test rejected")

    expect { expect(test.execute(execution)).to be(false) }
      .to output("    Rejected - #{LatexTesting::RED}FAIL#{LatexTesting::RESET}: Manual test rejected\n").to_stdout
    expect(test.failure_message).to eq("Manual test rejected")
  end

  it "uses exception messages in automated failure reports" do
    error_class = Class.new(StandardError) do
      def message
        "exception message"
      end

      def to_s
        "display string"
      end
    end
    test = described_class.new("Failure", fixture: Object.new, block: -> { raise error_class })

    expect { test.execute(Object.new) }.to output(/Failure: exception message/).to_stdout
    expect(test.failure_message).to eq("Failure: exception message")
  end

  it "supports direct failures with and without its own output prefix" do
    test = described_class.new("Rejected", fixture: Object.new, block: -> {})

    expect { expect(test.fail("not visible")).to be(false) }
      .to output("    Rejected - #{LatexTesting::RED}FAIL#{LatexTesting::RESET}: not visible\n").to_stdout
    expect(test.result).to eq(:failed)
    expect(test.failure_message).to eq("not visible")
    expect { test.fail("already prefixed", prefix: false) }
      .to output("#{LatexTesting::RED}FAIL#{LatexTesting::RESET}: already prefixed\n").to_stdout
  end

  it "stringifies its name and retains its fixture" do
    fixture = Object.new
    test = described_class.new(:Symbolic, fixture: fixture, block: -> {})

    expect(test.name).to eq("Symbolic")
    expect(test.fixture).to equal(fixture)
    expect(test.result).to be_nil
    expect(test.failure_message).to be_nil
  end
end

RSpec.describe LatexTesting::Assertion::Execution::PDFExecution::FrameProcessor do
  def new_processor
    resources = HexaPDF::Document.new.pages.add.resources
    described_class.new(resources)
  end

  it "captures immutable line strokes and resets the current path" do
    processor = new_processor
    processor.move_to(1, 2)
    processor.line_to(3, 2)
    processor.stroke_path
    processor.move_to(3, 2)
    processor.line_to(3, 5)
    processor.stroke_path

    expect(processor.strokes.map(&:index)).to eq([0, 1])
    expect(processor.strokes.map(&:points)).to eq([[[1, 2], [3, 2]], [[3, 2], [3, 5]]])
    expect(processor.strokes.map(&:color_space)).to eq(%i[DeviceGray DeviceGray])
    expect(processor.strokes.map(&:width)).to eq([1, 1])
    expect(processor.strokes.first.color).to be_frozen
    expect(processor.strokes.first.points).to be_frozen
  end

  it "rejects curved, compound, and filled stroke paths" do
    curved = new_processor
    curved.move_to(0, 0)
    curved.line_to(1, 0)
    curved.curve_to(1, 1, 2, 1, 2, 0)
    expect { curved.stroke_path }.to raise_error(/Unsupported frame path/)

    compound = new_processor
    compound.move_to(0, 0)
    compound.line_to(1, 0)
    compound.move_to(2, 0)
    compound.line_to(3, 0)
    expect { compound.stroke_path }.to raise_error(/Unsupported frame path/)

    filled = new_processor
    filled.move_to(0, 0)
    filled.line_to(1, 0)
    expect { filled.fill_and_stroke_path_non_zero }.to raise_error(/Unsupported frame path/)
  end

  it "discards fill-only paths and rejects unstarted lines" do
    processor = new_processor
    processor.move_to(0, 0)
    processor.line_to(1, 0)
    processor.fill_path_non_zero
    expect(processor.strokes).to be_empty

    processor.line_to(1, 0)
    expect { processor.stroke_path }.to raise_error(/Unsupported frame path/)
  end
end

RSpec.describe LatexTesting::Assertion::Execution::PDFExecution::FrameExtractor do
  include MutationCoverageSpecHelpers

  it "extracts sorted frames and groups colors and widths within tolerance" do
    strokes = rectangle_strokes(left: 10, bottom: 20, right: 30, top: 40)
    second = rectangle_strokes(left: 50, bottom: 60, right: 80, top: 90, width: 2.0001, color: [0.7501, 0, 0])
    second.each { |stroke| stroke.index += strokes.length }
    frames = described_class.new(strokes + second).extract

    expect(frames.first.left).to eq(9)
    expect(frames.last.left).to be_within(0.001).of(49)
    expect(frames.first.right).to eq(31)
    expect(frames.last.right).to be_within(0.001).of(81)
    expect(frames.map(&:color)).to eq([[0.75, 0, 0], [0.7501, 0, 0]])
    expect(frames.map(&:stroke_width)).to all(be_within(0.001).of(2))
  end

  it "rejects zero-width, diagonal, and incomplete frame geometry" do
    zero_width = rectangle_strokes
    zero_width.first.width = 0
    expect { described_class.new(zero_width).extract }.to raise_error(/stroke width must be positive/)

    diagonal = [frame_stroke(0, [[0, 0], [1, 1]])]
    expect { described_class.new(diagonal).extract }.to raise_error(/axis-aligned lines/)

    incomplete = rectangle_strokes
    incomplete.pop
    expect { described_class.new(incomplete).extract }.to raise_error(/do not form complete rectangular frames/)
  end
end

RSpec.describe LatexTesting::Assertion::Execution::PDFExecution::FramePartitioner do
  include MutationCoverageSpecHelpers

  it "finds exact partitions up to the requested limit" do
    strokes = rectangle_strokes
    expect(described_class.new(strokes).find(0)).to eq([])
    expect(described_class.new([]).find(2)).to eq([[]])
    partition = described_class.new(strokes).find(1).first.first
    expect(partition.map(&:index).sort).to eq([0, 1, 2, 3])

    second = rectangle_strokes(left: 50, bottom: 60, right: 80, top: 90)
    second.each { |stroke| stroke.index += strokes.length }
    expect(described_class.new(strokes + second).find(1).length).to eq(1)
    expect(described_class.new(strokes + second).find(2).length).to eq(1)
  end
end

RSpec.describe LatexTesting::Assertion::Execution::PDFExecution::FrameGeometry do
  include MutationCoverageSpecHelpers

  it "partitions axes, computes midpoints, and recognizes a rectangular candidate" do
    strokes = rectangle_strokes
    horizontal, vertical = described_class.partition(strokes)

    expect(horizontal.length).to eq(2)
    expect(vertical.length).to eq(2)
    expect(described_class.midpoint(vertical.first, :x)).to eq(90)
    expect(described_class.midpoint(horizontal.first, :y)).to eq(20)
    expect(described_class.candidates(strokes).map { |candidate| candidate.map(&:index).sort })
      .to eq([[0, 1, 2, 3]])
    expect(described_class.rectangular?(strokes)).to be(true)
    expect(described_class.rectangular?(strokes.first(3))).to be(false)
  end

  it "rejects inconsistent widths and non-matching rectangle edges" do
    inconsistent = rectangle_strokes
    inconsistent.last.width = 3
    expect(described_class.rectangular?(inconsistent)).to be(false)

    wrong_edge = rectangle_strokes
    wrong_edge.first.points[0][0] -= 5
    expect(described_class.rectangular?(wrong_edge)).to be(false)
  end
end

RSpec.describe LatexTesting, mutant_expression: ["LatexTesting*"] do
  include MutationCoverageSpecHelpers

  before do
    described_class.instance_variable_set(:@parsed_files, {})
    described_class.instance_variable_set(:@fixtures, {})
  end

  it "discovers overlapping definition patterns once in sorted path order" do
    Dir.mktmpdir do |directory|
      {
        "z_test.rb" => "Zed",
        "a_tests.rb" => "Alpha",
        "tests.rb" => "Tests",
        "test.rb" => "Test"
      }.each do |filename, name|
        File.write(File.join(directory, filename), <<~RUBY)
          fixture #{name.inspect} do
            test("fact") {}
          end
        RUBY
      end

      expect(described_class.scan(Pathname(directory)).map(&:name)).to eq(%w[Alpha Test Tests Zed])
    end
  end

  it "converts non-pathlike scan roots to strings" do
    Dir.mktmpdir do |directory|
      File.write(File.join(directory, "tests.rb"), "")
      base_dir = Object.new
      base_dir.define_singleton_method(:to_s) { directory }

      expect(described_class.send(:definition_files, base_dir)).to eq([File.join(directory, "tests.rb")])
    end
  end

  it "runs all registered fixtures when no selector is supplied" do
    Dir.mktmpdir do |directory|
      first = create_buildable_fixture(directory, name: "First")
      second = create_buildable_fixture(directory, name: "Second")
      described_class.register_fixture(first)
      described_class.register_fixture(second)
      expect(first).to receive(:execute).with({}, tests: first.tests)
      expect(second).to receive(:execute).with({}, tests: second.tests)

      described_class.run
    end
  end

  it "accepts a test when it belongs to the explicitly selected fixture" do
    fixture = LatexTesting::Fixture.new(
      "Selected", output_dir: "out/Selected", input_dir: ".", definition_file: "tests.rb"
    )
    test = fixture.test("Test") {}
    expect(fixture).to receive(:execute).with({ out_folder: "out" }, tests: [test])

    described_class.run({ out_folder: "out" }, fixture: fixture, test: test)
  end

  it "reports both definition files when fixture names collide" do
    Dir.mktmpdir do |directory|
      first_file = File.join(directory, "first_tests.rb")
      second_file = File.join(directory, "second_tests.rb")
      %w[first second].zip([first_file, second_file]).each do |name, filename|
        File.write(filename, "fixture 'Duplicate' do\n  test('#{name}') {}\nend\n")
      end

      expect { described_class.scan(directory) }.to raise_error(ArgumentError) { |error|
        expect(error.message).to include(
          "in #{second_file}",
          "(already defined in #{first_file})"
        )
      }
    end
  end

  it "omits fixtures without selected tests from the report" do
    with_tests = LatexTesting::Fixture.new(
      "With tests", output_dir: "out/With tests", input_dir: ".", definition_file: "tests.rb"
    )
    with_tests.test("Selected") {}
    without_tests = LatexTesting::Fixture.new(
      "Without tests", output_dir: "out/Without tests", input_dir: ".", definition_file: "tests.rb"
    )

    expect(described_class.send(:report_fixtures, [with_tests, without_tests], nil))
      .to eq([{ name: "With tests", tests: with_tests.tests }])
  end

  it "caches parsed files and rolls back all registrations after a failed parse" do
    Dir.mktmpdir do |directory|
      filename = File.join(directory, "tests.rb")
      File.write(filename, <<~RUBY)
        fixture "First" do
          test("fact") {}
        end
        fixture "Broken" do
        end
      RUBY

      Dir.chdir(directory) do
        expect { described_class.parse_file("tests.rb") }.to raise_error(ArgumentError, /has no tests/)
      end
      expect(described_class.instance_variable_get(:@fixtures)).to be_empty

      File.write(filename, <<~RUBY)
        fixture "Recovered" do
          test("fact") {}
        end
      RUBY
      parsed = Dir.chdir(directory) { described_class.parse_file("tests.rb") }

      expect(Dir.chdir(directory) { described_class.parse_file("tests.rb") }).to equal(parsed)
      expect(described_class.instance_variable_get(:@parsed_files).keys).to eq([filename])
      expect(parsed.map(&:name)).to eq(["Recovered"])
    end
  end

  it "reports syntax errors using the source file's actual line numbers" do
    Dir.mktmpdir do |directory|
      filename = File.join(directory, "tests.rb")
      File.write(filename, "fixture 'Broken' do\n  test(\nend\n")

      expect { described_class.parse_file(filename) }
        .to raise_error(SyntaxError, /#{Regexp.escape(filename)}:3:/)
    end
  end
end

RSpec.describe LatexTesting::DefinitionContext, mutant_expression: ["LatexTesting::DefinitionContext*"] do
  it "expands the definition filename and evaluates declarations against their fixture" do
    Dir.mktmpdir("latextesting-") do |directory|
      expect(directory).to start_with("/tmp/")
      filename = File.join(directory, "tests.rb")
      fixture_files = []
      relative_filename = Pathname(filename).relative_path_from(LatexTesting::PROJECT_ROOT)
      context = described_class.new(relative_filename, fixture_files)
      File.write(File.join(directory, "fixture.tex"), "")

      fixture = context.fixture("Card") do
        file "fixture.tex"
        test("has a title") { expect(File.basename(pdf_path)).to eq("Card.pdf") }
      end

      expect(context.filename).to eq(File.expand_path(relative_filename))
      expect(context.fixtures).to equal(fixture_files)
      expect(fixture_files).to eq([fixture])
      expect(fixture.instance_variable_get(:@input_dir)).to eq(directory)
      expect(fixture.definition_file).to eq(File.expand_path(relative_filename))
      relative_output_dir =
        Pathname(filename).relative_path_from(LatexTesting::PROJECT_ROOT).to_s.delete_suffix(".rb")
      expect(fixture.instance_variable_get(:@output_dir))
        .to eq(File.join(LatexTesting::OUT_DIR, relative_output_dir, "Card"))
    end
  end

  it "stringifies symbolic fixture names and registers fixtures" do
    LatexTesting.instance_variable_set(:@fixtures, {})
    context = described_class.new("tests.rb", [])
    fixture = context.fixture(:Symbolic) do
      test("fact") {}
    end

    expect(fixture.name).to eq("Symbolic")
    expect(fixture.instance_variable_get(:@output_dir)).to end_with("/Symbolic")
    expect(LatexTesting.instance_variable_get(:@fixtures)).to eq("Symbolic" => fixture)
  end

  it "requires a fixture declaration block and at least one test" do
    context = described_class.new("tests.rb", [])

    expect { context.fixture("Missing block") }.to raise_error(RuntimeError, "fixture defined without data")
    expect { context.fixture("No tests") {} }
      .to raise_error(ArgumentError, "fixture 'No tests' has no tests")
  end
end

RSpec.describe LatexTesting::Fixture, mutant_expression: ["LatexTesting::Fixture*"] do
  include MutationCoverageSpecHelpers

  it "returns immediately for an empty test selection" do
    fixture = described_class.new("Empty", output_dir: "out/Empty", input_dir: ".", definition_file: "tests.rb")
    expect(fixture).not_to receive(:build_raw)
    expect(Dir).not_to receive(:mktmpdir)

    expect(fixture.execute).to be(true)
  end

  it "adds named, manual, and log tests and rejects duplicate names" do
    fixture = described_class.new("Card", output_dir: "out/Card", input_dir: ".", definition_file: "tests.rb")
    automated = fixture.test(:Title) {}
    manual = fixture.manual_test("Visible title")
    log = fixture.requires_log("warning")

    expect(fixture.tests).to eq([automated, manual, log])
    expect(automated.fixture).to equal(fixture)
    expect(automated.name).to eq("Title")
    expect(manual.name).to eq("Visible title")
    expect(log.name).to eq("Log contains 'warning'")
    expect { fixture.test("Title") {} }
      .to raise_error(ArgumentError, "duplicate test name 'Title' in fixture 'Card'")
  end

  it "runs selected tests with merged options and returns their result" do
    Dir.mktmpdir do |directory|
      fixture = create_buildable_fixture(directory)
      selected = fixture.manual_test("Selected")
      fixture.test("Not selected") { raise "should not run" }
      allow($stdin).to receive(:gets).and_return("yes\n")
      expect(Dir).to receive(:mktmpdir).with("latex-testing-").and_call_original
      expect(fixture).to receive(:execute_tests_in)
        .with(anything, [selected], { custom_option: true, user_interaction: true }).and_call_original
      expect(fixture).to receive(:build_raw)
        .with(File.join(directory, "fixture.tex"), anything).and_call_original

      expect do
        fixture.execute({ user_interaction: false, custom_option: true }, tests: [selected], user_interaction: true)
      end
        .to output(/Selected.*Does this test pass?.*PASSED/m).to_stdout
      expect(selected.result).to eq(:passed)
    end
  end

  it "exposes the persisted PDF path to fixture test assertions" do
    Dir.mktmpdir do |directory|
      fixture = create_buildable_fixture(directory)
      expected_path = File.join(directory, "out", "Fixture.pdf")
      test = fixture.test("PDF path") do
        raise "unexpected PDF path" unless pdf_path == expected_path
      end

      expect { fixture.execute }.to output(/PDF path.*PASS/m).to_stdout
      expect(test.result).to eq(:passed)
    end
  end

  it "skips manual checks when fixture execution is non-interactive" do
    Dir.mktmpdir do |directory|
      fixture = create_buildable_fixture(directory)
      test = fixture.manual_test("No interaction")
      expect($stdin).not_to receive(:gets)

      expect { fixture.execute(user_interaction: false) }
        .to output(/No interaction.*MANUAL TEST SKIPPED/m).to_stdout
      expect(test.result).to eq(:manual_test_skipped)
    end
  end

  it "requires code for automated tests and checks required log snippets" do
    fixture = described_class.new("Card", output_dir: "out/Card", input_dir: ".", definition_file: "tests.rb")
    expect { fixture.test("Missing block") }.to raise_error(RuntimeError, "test defined without code block")

    Dir.mktmpdir do |directory|
      passing = create_buildable_fixture(directory)
      passing.requires_log("build log")
      expect { expect(passing.execute).to be(true) }.to output(/Log contains .*PASS/).to_stdout

      failing = create_buildable_fixture(directory, name: "Other")
      test = failing.requires_log("absent")
      expect { expect(failing.execute).to be(false) }.to output(/FAIL.*Not found/).to_stdout
      expect(test.failure_message).to eq("Log contains 'absent': Not found")
    end
  end

  it "continues running later tests after one fails" do
    Dir.mktmpdir do |directory|
      fixture = create_buildable_fixture(directory)
      later_test_ran = false
      first = fixture.test("Failure") { raise "expected failure" }
      later = fixture.test("Later") { later_test_ran = true }

      expect { expect(fixture.execute).to be(false) }
        .to output(/Failure.*FAIL.*Later.*PASS/m).to_stdout
      expect(first.result).to eq(:failed)
      expect(later.result).to eq(:passed)
      expect(later_test_ran).to be(true)
    end
  end

  it "stringifies fixture names and marks every selected test failed after build failure" do
    Dir.mktmpdir do |directory|
      fixture = described_class.new(
        :Card,
        output_dir: File.join(directory, "out", "Card"),
        input_dir: directory,
        definition_file: File.join(directory, "tests.rb")
      )
      fixture.file("fixture.tex")
      File.write(File.join(directory, "fixture.tex"), "")
      fixture.define_singleton_method(:build_raw) { |_source, _temp_dir| false }
      first = fixture.test("First") { raise "not executed" }
      second = fixture.test("Second") { raise "not executed" }

      expect(fixture.name).to eq("Card")
      expect(fixture.definition_file).to eq(File.join(directory, "tests.rb"))
      expect(fixture.instance_variable_get(:@output_pdf_path))
        .to eq(File.join(directory, "out", "Card.pdf"))
      expect { expect(fixture.execute).to be(false) }
        .to output(/Card.*First.*Build did not pass.*Second.*Build did not pass/m).to_stdout
      expect([first.result, second.result]).to eq(%i[failed failed])
      expect(first.failure_message).to eq("fixture.tex: Build did not pass")
    end

    Dir.mktmpdir do |directory|
      missing_file = described_class.new(
        :Named,
        output_dir: File.join(directory, "out", "Named"),
        input_dir: directory,
        definition_file: File.join(directory, "tests.rb")
      )
      missing_file.test("Build diagnostic") {}
      expect { expect(missing_file.execute).to be(false) }
        .to output(/Build diagnostic.*Named: no \.tex file given/).to_stdout
      expect(File.exist?(File.join(directory, "out", "Named.log"))).to be(false)
    end
  end

  it "runs log assertions after an expected compilation failure" do
    Dir.mktmpdir do |directory|
      fixture = create_buildable_fixture(directory)
      fixture.expect_compilation_failure
      fixture.define_singleton_method(:build_raw) do |_source, temp_dir|
        File.write(File.join(temp_dir, "fixture.log"), "expected diagnostic")
        false
      end
      log_test = fixture.requires_log("expected diagnostic")

      expect { expect(fixture.execute).to be(true) }
        .to output(/Log contains .*PASS/).to_stdout
      expect(log_test.result).to eq(:passed)
    end
  end
end

RSpec.describe LatexTesting::Assertion::Execution, mutant_expression: ["LatexTesting::Assertion::Execution*"] do
  it "reads and caches the build log and rejects a missing log" do
    Dir.mktmpdir do |directory|
      log_path = File.join(directory, "fixture.log")
      File.write(log_path, "compiler output")
      execution = described_class.new(directory, "fixture.tex")
      expect(File).to receive(:read).with(log_path).once.and_call_original

      expect(execution.log).to eq("compiler output")
      expect(execution.log).to eq("compiler output")
    end

    Dir.mktmpdir do |directory|
      execution = described_class.new(directory, "fixture.tex")
      expect { execution.log }.to raise_error("No log file produced by LaTeX build")
    end
  end

  it "uses a source basename when locating temporary build files" do
    Dir.mktmpdir do |directory|
      File.write(File.join(directory, "fixture.log"), "nested source log")
      execution = described_class.new(directory, "chapter/fixture.tex")
      expect(execution.log).to eq("nested source log")
    end
  end

  it "uses the persistent PDF path when given and otherwise uses the temporary build PDF" do
    Dir.mktmpdir do |directory|
      temp_pdf = File.join(directory, "fixture.pdf")
      File.write(temp_pdf, "pdf")
      execution = described_class.new(directory, "fixture.tex")
      expect(execution.pdf_path).to eq(temp_pdf)

      output_pdf = File.join(directory, "saved.pdf")
      File.write(output_pdf, "pdf")
      persistent = described_class.new(directory, "fixture.tex", output_pdf_path: output_pdf)
      expect(persistent.pdf_path).to eq(output_pdf)
      expect do
        described_class.new(directory, "fixture.tex", output_pdf_path: "missing.pdf").pdf_path
      end.to raise_error("No PDF file produced by LaTeX build")
    end
  end

  it "skips manual checks without interaction and retries invalid answers" do
    Dir.mktmpdir do |directory|
      File.write(File.join(directory, "fixture.pdf"), "pdf")
      skipped = described_class.new(directory, "fixture.tex")
      expect(skipped.manual_test("visible")).to eq(:manual_test_skipped)

      interactive = described_class.new(directory, "fixture.tex", user_interaction: true)
      allow($stdin).to receive(:gets).and_return("maybe\n", "  YES\n")
      expect { expect(interactive.manual_test("visible")).to eq(:manual_test_passed) }
        .to output("PDF: #{File.join(directory, "fixture.pdf")}\n" \
                   "Does this test pass? [yes/no] \n" \
                   "Does this test pass? [yes/no] \n").to_stdout
    end

    Dir.mktmpdir do |directory|
      execution = described_class.new(directory, "fixture.tex")
      expect { execution.manual_test("visible") }
        .to raise_error("No PDF file produced by LaTeX build")
    end

    Dir.mktmpdir do |directory|
      File.write(File.join(directory, "fixture.pdf"), "pdf")
      execution = described_class.new(directory, "fixture.tex", user_interaction: true)
      allow($stdin).to receive(:gets).and_return(nil)
      expect { execution.manual_test("visible") }
        .to raise_error("No response received for manual test")
    end
  end

  it "accepts short manual answers and reports the rejected test name" do
    Dir.mktmpdir do |directory|
      File.write(File.join(directory, "fixture.pdf"), "pdf")

      accepted = described_class.new(directory, "fixture.tex", user_interaction: true)
      allow($stdin).to receive(:gets).and_return("y\n")
      expect { expect(accepted.manual_test("accepted")).to eq(:manual_test_passed) }
        .to output(/Does this test pass\?/).to_stdout

      rejected = described_class.new(directory, "fixture.tex", user_interaction: true)
      allow($stdin).to receive(:gets).and_return("no\n")
      expect do
        expect { rejected.manual_test("specific title") }
          .to raise_error("Manual test rejected: specific title")
      end.to output(/Does this test pass\?/).to_stdout

      short_rejection = described_class.new(directory, "fixture.tex", user_interaction: true)
      allow($stdin).to receive(:gets).and_return("n\n")
      expect { expect { short_rejection.manual_test("short") }.to raise_error(/Manual test rejected: short/) }
        .to output(/Does this test pass\?/).to_stdout
    end
  end

  it "opens a generated PDF once and forwards RSpec assertions" do
    Dir.mktmpdir do |directory|
      pdf_path = File.join(directory, "fixture.pdf")
      HexaPDF::Document.new.write(pdf_path)
      execution = described_class.new(directory, "fixture.tex")
      expect(execution).to receive(:require).with("hexapdf").and_call_original
      expect(HexaPDF::Document).to receive(:open).with(pdf_path).once.and_call_original

      generated = execution.generated_pdf
      expect(generated).to be_a(LatexTesting::Assertion::Execution::PDFExecution)
      expect(execution.generated_pdf).to equal(generated)
      expect { generated.expect(false).to be(true) }
        .to raise_error(RSpec::Expectations::ExpectationNotMetError)
    end
  end
end

RSpec.describe LatexTesting::JUnitReport, mutant_expression: ["LatexTesting::JUnitReport*"] do
  it "writes fixture and suite totals with failure details" do
    test_result = Struct.new(:name, :result, :failure_message)
    passing = test_result.new("visible", :passed, nil)
    failing = test_result.new("valid & <safe>", :failed, "bad & <value>")
    fixtures = [
      { name: "Card & <front>", tests: [passing, failing] },
      { name: "Back", tests: [] }
    ]

    document = described_class.build_document(fixtures)
    root = document.root
    suites = root.get_elements("testsuite")
    cases = suites.first.get_elements("testcase")

    expect(document.xml_decl.version).to eq("1.0")
    expect(document.xml_decl.encoding).to eq("UTF-8")
    expect(root.attributes["tests"]).to eq("2")
    expect(root.attributes["failures"]).to eq("1")
    expect(root.attributes["errors"]).to eq("0")
    expect(root.attributes["skipped"]).to eq("0")
    expect(suites.map { |suite| suite.attributes["name"] }).to eq(["Card & <front>", "Back"])
    expect(suites.first.attributes["tests"]).to eq("2")
    expect(suites.first.attributes["failures"]).to eq("1")
    expect(suites.last.attributes["tests"]).to eq("0")
    expect(cases.first.elements["failure"]).to be_nil
    expect(cases.last.attributes["classname"]).to eq("Card & <front>")
    expect(cases.last.attributes["name"]).to eq("valid & <safe>")
    expect(cases.last.elements["failure"].attributes["message"]).to eq("bad & <value>")
    expect(cases.last.elements["failure"].text).to eq("bad & <value>")
    expect(described_class.summary_attributes([passing, failing]))
      .to eq("tests" => "2", "failures" => "1", "errors" => "0", "skipped" => "0")
    expect(described_class.fixture_attributes({ name: :Card }, [passing])["name"]).to eq("Card")
    attributes = described_class.fixture_attributes({ name: :Card }, [passing])
    expect(attributes["tests"]).to eq("1")
    expect(attributes["failures"]).to eq("0")
    expect(attributes["errors"]).to eq("0")
    expect(attributes["skipped"]).to eq("0")
    missing_message = test_result.new("Missing failure details", :failed, nil)
    missing_message_document = described_class.build_document([{ name: "Card", tests: [missing_message] }])
    expect(missing_message_document.elements["testsuites/testsuite/testcase/failure"].attributes["message"])
      .to eq("")
  end

  it "creates report directories and writes a trailing newline" do
    Dir.mktmpdir do |directory|
      filename = File.join(directory, "reports", "junit.xml")
      described_class.write(filename, [])

      report = File.read(filename)
      expect(report).to match(/\A<\?xml version=['"]1\.0['"] encoding=['"]UTF-8['"]\?>/)
      expect(report).to end_with("\n")
      expect(REXML::Document.new(report).root.name).to eq("testsuites")
    end
  end

  it "accepts path objects and stringifies fixture and test names" do
    test_result = Struct.new(:name, :result, :failure_message).new(:symbolic, :passed, nil)
    Dir.mktmpdir do |directory|
      filename = Pathname(directory).join("nested", "report.xml")

      described_class.write(filename, [{ name: :card, tests: [test_result] }])

      testcase = REXML::Document.new(File.read(filename)).elements["testsuites/testsuite/testcase"]
      expect(testcase.attributes["classname"]).to eq("card")
      expect(testcase.attributes["name"]).to eq("symbolic")
    end
  end
end

RSpec.describe LatexTesting::Assertion::Execution::PDFExecution,
               mutant_expression: ["LatexTesting::Assertion::Execution::PDFExecution*"] do
  it "caches wrapped pages and delegates assertion helpers before document methods",
     mutant_expression: ["LatexTesting::Assertion::Execution::PDFExecution*"] do
    document_pages = HexaPDF::Document.new.pages
    document_pages.add
    document = Struct.new(:pages, :document_title, :version)
                     .new(document_pages, "document title", 1)
    execution = Struct.new(:log, :document_title).new("cached log", "assertion title")
    proxy = described_class.new(execution, document)

    expect(proxy.pages).to be_a(LatexTesting::Assertion::Execution::PDFExecution::PageCollection)
    expect(proxy.pages).to equal(proxy.pages)
    expect(proxy.pages[0]).to be_a(LatexTesting::Assertion::Execution::PDFExecution::Page)
    expect(proxy.log).to eq("cached log")
    expect(proxy.document_title).to eq("assertion title")
    expect(proxy.version).to eq(1)
    expect(proxy.respond_to?(:document_title)).to be(true)
    expect(proxy.respond_to?(:pages)).to be(true)
    expect(proxy.respond_to?(:log)).to be(true)
    expect(proxy.respond_to?(:version)).to be(true)
    expect(proxy.respond_to?(:no_such_document_method)).to be(false)
    expect { proxy.no_such_document_method }.to raise_error(NoMethodError)
  end

  it "forwards arguments, keywords, and blocks to delegated methods" do
    execution = Object.new
    execution.define_singleton_method(:transform) do |value, scale:, &block|
      block.call(value * scale)
    end
    document = Struct.new(:pages).new(HexaPDF::Document.new.pages)
    proxy = described_class.new(execution, document)

    expect(proxy.transform(3, scale: 4) { |value| value + 1 }).to eq(13)
  end

  it "respects private methods when answering visibility queries" do
    execution = Object.new
    execution.define_singleton_method(:internal_value) { :hidden }
    execution.singleton_class.send(:private, :internal_value)
    document = Struct.new(:pages).new(HexaPDF::Document.new.pages)
    document.define_singleton_method(:document_internal_value) { :hidden }
    document.singleton_class.send(:private, :document_internal_value)
    proxy = described_class.new(execution, document)

    expect(proxy.respond_to?(:internal_value)).to be(false)
    expect(proxy.respond_to?(:internal_value, true)).to be(true)
    expect(proxy.respond_to?(:document_internal_value)).to be(false)
    expect(proxy.respond_to?(:document_internal_value, true)).to be(true)
  end
end

RSpec.describe LatexTesting::Assertion::Execution::PDFExecution::PageCollection,
               mutant_expression: ["LatexTesting::Assertion::Execution::PDFExecution::PageCollection*"] do
  it "wraps indexed, ranged, and enumerated page results consistently",
     mutant_expression: ["LatexTesting::Assertion::Execution::PDFExecution::PageCollection*"] do
    document_pages = HexaPDF::Document.new.pages
    pages = [document_pages.add, document_pages.add]
    collection = described_class.new(pages)
    first = collection[0]

    expect(first).to be_a(LatexTesting::Assertion::Execution::PDFExecution::Page)
    expect(collection[0]).to equal(first)
    expect(collection[1..]).to all(be_a(LatexTesting::Assertion::Execution::PDFExecution::Page))
    expect(collection[5]).to be_nil
    expect(collection.index(pages.first)).to eq(0)
    expect(collection.each).to be_a(Enumerator)
    expect(collection.each.to_a).to all(be_a(LatexTesting::Assertion::Execution::PDFExecution::Page))
    expect(collection.each(&:boundary)).to equal(collection)
    expect(collection.length).to eq(2)
    expect(collection.size).to eq(2)
    expect(collection.respond_to?(:length)).to be(true)
    expect(collection.respond_to?(:index)).to be(true)
    expect(collection.respond_to?(:no_such_page_method)).to be(false)
    expect(collection.values_at(1)).to eq([collection[1]])
    expect { collection.no_such_page_method }.to raise_error(NoMethodError) { |error|
      expect(error.receiver).to equal(collection)
    }
  end

  it "delegates length without enumerating pages" do
    pages = Class.new(Array) do
      def length
        17
      end
    end.new([Object.new, Object.new])
    collection = described_class.new(pages)

    expect(collection.length).to eq(17)
  end

  it "forwards arguments, keywords, and blocks to delegated page methods" do
    pages = Object.new
    pages.define_singleton_method(:transform) do |value, scale:, &block|
      block.call(value * scale)
    end
    collection = described_class.new(pages)

    expect(collection.transform(3, scale: 4) { |value| value + 1 }).to eq(13)
  end

  it "respects private visibility when delegating page collection methods" do
    pages = []
    pages.define_singleton_method(:internal_value) { :hidden }
    pages.singleton_class.send(:private, :internal_value)
    collection = described_class.new(pages)

    expect(collection.respond_to?(:internal_value)).to be(false)
    expect(collection.respond_to?(:internal_value, true)).to be(true)
    expect { collection.internal_value }.to raise_error(NoMethodError) { |error|
      expect(error.receiver).to equal(collection)
    }
  end

  it "caches page proxies by identity rather than equality" do
    page_class = Class.new do
      def box(*)
        nil
      end

      def hash
        1
      end

      def eql?(_other)
        true
      end
    end
    pages = [page_class.new, page_class.new]
    collection = described_class.new(pages)

    expect(collection[0]).not_to equal(collection[1])
  end
end

RSpec.describe LatexTesting::Assertion::Execution::PDFExecution::Page,
               mutant_expression: ["LatexTesting::Assertion::Execution::PDFExecution::Page*"] do
  it "caches immutable media boundaries and delegates page operations" do
    page = HexaPDF::Document.new.pages.add
    expected_bounds = [page.box(:media).width, page.box(:media).height]
    proxy = described_class.new(page)
    expect(page).to receive(:box).with(:media).once.and_call_original

    boundary = proxy.boundary
    expect(boundary).to equal(proxy.boundary)
    expect([boundary.width, boundary.height]).to eq(expected_bounds)
    expect { boundary.left = 0 }.to raise_error(FrozenError)
    expect(proxy.contents).to eq(page.contents)
    expect(proxy.respond_to?(:contents)).to be(true)
    expect(proxy.respond_to?(:no_such_page_method)).to be(false)
    expect { proxy.no_such_page_method }.to raise_error(NoMethodError) { |error|
      expect(error.receiver).to equal(proxy)
    }
  end

  it "converts numeric values and rejects invalid units" do
    page = HexaPDF::Document.new.pages.add
    page[:UserUnit] = 2
    proxy = described_class.new(page)

    expect(proxy.convert_unit(72, 0.5)).to eq(72)
    expect { proxy.convert_unit("72", 0.5) }.to raise_error(ArgumentError, /must be numeric/)
    expect { proxy.convert_unit(72, nil) }.to raise_error(ArgumentError, /must be numeric/)
    expect { proxy.convert_unit(72, "0.5") }.to raise_error(ArgumentError, /must be numeric/)

    default_unit_page = HexaPDF::Document.new.pages.add
    expect(described_class.new(default_unit_page).convert_unit(72, 0.5)).to eq(36)
  end

  it "returns an empty cached frame collection for pages without stroked paths" do
    proxy = described_class.new(HexaPDF::Document.new.pages.add)
    expect(proxy).to receive(:require).with("hexapdf").and_call_original

    frames = proxy.frames
    expect(frames.to_a).to be_empty
    expect(proxy.frames).to equal(frames)
  end

  it "forwards keyword arguments and blocks while respecting private visibility" do
    page = Object.new
    page.define_singleton_method(:transform) { |value, factor:, &block| block.call(value * factor) }
    page.define_singleton_method(:internal_value) { :hidden }
    page.singleton_class.send(:private, :internal_value)
    proxy = described_class.new(page)

    expect(proxy.transform(3, factor: 4) { |value| value + 1 }).to eq(13)
    expect(proxy.respond_to?(:transform)).to be(true)
    expect(proxy.respond_to?(:internal_value)).to be(false)
    expect(proxy.respond_to?(:internal_value, true)).to be(true)
    expect(proxy.respond_to?(:missing_page_method)).to be(false)
    expect { proxy.internal_value }.to raise_error(NoMethodError) { |error|
      expect(error.receiver).to equal(proxy)
    }
  end
end

RSpec.describe LatexTesting::Assertion::Execution::PDFExecution::Frame,
               mutant_expression: ["LatexTesting::Assertion::Execution::PDFExecution::Frame*"] do
  it "exposes dimensions and named frame properties while rejecting unknown keys" do
    color = described_class::Color.new(:DeviceRGB, [0.5, 0.25, 0])
    frame = described_class.new(
      color: color,
      stroke_width: 2,
      bounds: { left: 10, bottom: 20, right: 50, top: 80 }
    )

    expect(frame.width).to eq(40)
    expect(frame.height).to eq(60)
    expect(frame[:left]).to eq(10)
    expect(frame[:right]).to eq(50)
    expect(frame[:bottom]).to eq(20)
    expect(frame[:top]).to eq(80)
    expect(frame[:color]).to equal(color)
    expect(frame[:stroke_width]).to eq(2)
    expect(frame[:width]).to eq(40)
    expect(frame[:height]).to eq(60)
    expect { frame[:diagonal] }.to raise_error(KeyError, /Unknown frame property/)
    expect { frame["missing"] }.to raise_error(KeyError, 'Unknown frame property: "missing"')
    expect { frame.left = 0 }.to raise_error(NoMethodError)
    expect { frame.instance_variable_set(:@extra, true) }.to raise_error(FrozenError)
    expect(color.components).to eq([0.5, 0.25, 0])
    expect(color.components).to equal(color)
    expect(color.color_space).to eq(:DeviceRGB)
    expect { color << 1 }.to raise_error(FrozenError)
  end
end

RSpec.describe LatexTesting::Assertion::Execution::PDFExecution::FrameCollection,
               mutant_expression: ["LatexTesting::Assertion::Execution::PDFExecution::FrameCollection*"] do
  it "enumerates frames and enforces a predicate with exactly one match" do
    frames = [
      LatexTesting::Assertion::Execution::PDFExecution::Frame.new(
        color: :red, stroke_width: 2, bounds: { left: 0, bottom: 0, right: 10, top: 10 }
      ),
      LatexTesting::Assertion::Execution::PDFExecution::Frame.new(
        color: :blue, stroke_width: 2, bounds: { left: 20, bottom: 0, right: 30, top: 10 }
      )
    ]
    collection = described_class.new(frames)

    expect(collection.each).to be_a(Enumerator)
    expect(collection.each.to_a).to eq(frames)
    expect(collection.each(&:width)).to equal(frames)
    expect(collection.map(&:color)).to eq(%i[red blue])
    expect(collection.single { |frame| frame.color == :blue }).to equal(frames.last)
    expect { collection.single }.to raise_error(ArgumentError, /requires a predicate/)
    expect { collection.single { false } }.to raise_error(/found none/)
    expect { collection.single { true } }.to raise_error(/found 2/)
    expect { collection.instance_variable_get(:@frames) << :extra }.to raise_error(FrozenError)
    expect { collection.instance_variable_set(:@extra, true) }.to raise_error(FrozenError)
  end
end

RSpec.describe LatexTesting::Fixture::Builder, mutant_expression: ["LatexTesting::Fixture::Builder*"] do
  def create_builder(directory, file: "card.tex", expect_failure: false, &build)
    input_dir = File.join(directory, "input")
    output_dir = File.join(directory, "output", "Card")
    output_pdf_path = File.join(directory, "output", "Card.pdf")
    FileUtils.mkdir_p(File.join(input_dir, File.dirname(file)))
    FileUtils.mkdir_p(File.join(directory, "temp"))
    File.write(File.join(input_dir, file), "")
    builder = described_class.new(
      name: "Card",
      file: file,
      input_dir: input_dir,
      output_dir: output_dir,
      output_pdf_path: output_pdf_path,
      expect_compilation_failure: expect_failure,
      build: build
    )
    [builder, output_dir, output_pdf_path]
  end

  it "validates the source, clears stale output, and persists successful PDFs" do
    Dir.mktmpdir do |directory|
      builder, output_dir, output_pdf_path = create_builder(directory) do |source, temp_dir|
        expect(source).to be_a(String)
        expect(File.basename(source)).to eq("card.tex")
        File.write(File.join(temp_dir, "card.pdf"), "new pdf")
        File.write(File.join(temp_dir, "card.log"), "new log")
        true
      end
      output_log_path = File.join(File.dirname(output_pdf_path), "Card.log")
      FileUtils.mkdir_p(output_dir)
      File.write(File.join(output_dir, "fixture.pdf"), "old pdf")
      File.write(File.join(output_dir, "fixture.log"), "old log")
      File.write(output_pdf_path, "stale pdf")
      File.write(output_log_path, "stale log")

      expect(builder.build(File.join(directory, "temp"))).to be_nil

      expect(File.read(output_pdf_path)).to eq("new pdf")
      expect(File.exist?(output_log_path)).to be(false)
      expect(File.exist?(File.join(output_dir, "fixture.pdf"))).to be(false)
      expect(File.exist?(File.join(output_dir, "fixture.log"))).to be(false)
    end
  end

  it "saves logs for expected failures and reports unexpected build results" do
    Dir.mktmpdir do |directory|
      builder, _output_dir, output_pdf_path = create_builder(directory, expect_failure: true) do |_source, temp_dir|
        File.write(File.join(temp_dir, "card.log"), "expected diagnostic")
        false
      end

      expect(builder.build(File.join(directory, "temp"))).to be_nil
      expect(File.read(File.join(File.dirname(output_pdf_path), "Card.log"))).to eq("expected diagnostic")
      expect(File.exist?(output_pdf_path)).to be(false)
    end

    Dir.mktmpdir do |directory|
      builder, _output_dir, output_pdf_path = create_builder(directory) do |_source, _temp_dir|
        false
      end

      expect(builder.build(File.join(directory, "temp"))).to eq("card.tex: Build did not pass")
      expect(File.read(File.join(File.dirname(output_pdf_path), "Card.log"))).to eq("Build failed for card.tex")
    end
  end

  it "reports missing sources and successful builds without PDFs" do
    Dir.mktmpdir do |directory|
      builder, output_dir, output_pdf_path = create_builder(directory) { true }
      FileUtils.rm_f(File.join(directory, "input", "card.tex"))

      expect(builder.build(File.join(directory, "temp"))).to eq("card.tex: card.tex not found")
      expect(File.exist?(File.join(File.dirname(output_pdf_path), "Card.log"))).to be(false)
      expect(File.exist?(output_dir)).to be(false)
    end

    Dir.mktmpdir do |directory|
      builder, _output_dir, output_pdf_path = create_builder(directory) do |_source, temp_dir|
        File.write(File.join(temp_dir, "card.log"), "compiler completed")
        true
      end

      expect(builder.build(File.join(directory, "temp"))).to eq("card.tex: Build completed without producing a PDF")
      expect(File.read(File.join(File.dirname(output_pdf_path), "Card.log"))).to eq("compiler completed")
    end
  end

  it "rejects a missing source declaration and unexpected successful negative builds" do
    Dir.mktmpdir do |directory|
      input_dir = File.join(directory, "input")
      builder = described_class.new(
        name: "Card",
        file: nil,
        input_dir: input_dir,
        output_dir: File.join(directory, "output", "Card"),
        output_pdf_path: File.join(directory, "output", "Card.pdf"),
        expect_compilation_failure: false,
        build: ->(*) { true }
      )

      expect(builder.build(File.join(directory, "temp"))).to eq("Card: no .tex file given")
    end

    Dir.mktmpdir do |directory|
      builder, _output_dir, output_pdf_path = create_builder(directory, expect_failure: true) do |_source, temp_dir|
        File.write(File.join(temp_dir, "card.pdf"), "pdf")
        File.write(File.join(temp_dir, "card.log"), "unexpected success")
        true
      end

      expect(builder.build(File.join(directory, "temp"))).to eq("card.tex: Build passed unexpectedly")
      expect(File.read(File.join(File.dirname(output_pdf_path), "Card.log"))).to eq("unexpected success")
    end
  end

  it "uses exception messages rather than exception string representations" do
    Dir.mktmpdir do |directory|
      custom_error = Class.new(StandardError) do
        def message
          "exception message"
        end

        def to_s
          "display string"
        end
      end.new("exception message")
      builder, = create_builder(directory) { raise custom_error }

      expect(builder.build(File.join(directory, "temp")))
        .to eq("card.tex: exception message")
    end
  end

  it "clears a stale output PDF after an expected failed rebuild" do
    Dir.mktmpdir do |directory|
      builder, _output_dir, output_pdf_path = create_builder(directory, expect_failure: true) do |_source, temp_dir|
        File.write(File.join(temp_dir, "card.log"), "expected diagnostic")
        false
      end
      FileUtils.mkdir_p(File.dirname(output_pdf_path))
      File.write(output_pdf_path, "stale pdf")

      expect(builder.build(File.join(directory, "temp"))).to be_nil
      expect(File.exist?(output_pdf_path)).to be(false)
    end
  end

  it "uses only the source basename for temporary output files" do
    Dir.mktmpdir do |directory|
      builder, output_dir = create_builder(directory, file: "chapter/card.tex") do |_source, temp_dir|
        File.write(File.join(temp_dir, "card.pdf"), "pdf")
        true
      end

      expect(builder.build(File.join(directory, "temp"))).to be_nil
      expect(File.exist?(output_dir)).to be(false)
    end
  end

  # rubocop:enable Metrics/BlockLength, Metrics/MethodLength, Metrics/ParameterLists
end
