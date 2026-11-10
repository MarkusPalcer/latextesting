# frozen_string_literal: true

RSpec.describe LatexTesting do
  it "has a version number" do
    expect(LatexTesting::VERSION).not_to be nil
  end

  it "loads the test framework classes" do
    expect(described_class::TestFile).to be_a(Class)
    expect(described_class::TestSuite).to be_a(Class)
    expect(described_class::Test).to be_a(Class)
    expect(described_class::Assertion).to be_a(Class)
    expect(described_class::Assertion::Execution).to be_a(Class)
  end

  it "returns the nonempty suites discovered by scan" do
    filename = nil
    begin
      Dir.mktmpdir do |directory|
        filename = File.join(directory, "sample_tests.rb")
        File.write(filename, <<~RUBY)
          testsuite "Suite / With: Punctuation" do
            test "Single test?!" do
            end
          end
        RUBY

        suites = described_class.scan(directory)
        expect(suites.map(&:name)).to eq(["Suite / With: Punctuation"])
        expect(suites.first.tests.map(&:name)).to eq(["Single test?!"])
      end
    ensure
      described_class.instance_variable_get(:@files).delete(File.expand_path(filename)) if filename
    end
  end

  it "runs only the requested suite or test" do
    suite = described_class::TestSuite.new("Suite", output_dir: "out", input_dir: "test")
    selected_test = suite.test("Selected") {}
    other_test = suite.test("Other") {}

    expect(suite).to receive(:execute).with({ out_folder: "out" })
    described_class.run(out_folder: "out", suite: suite)

    expect(selected_test).to receive(:execute).with({ out_folder: "out" })
    expect(other_test).not_to receive(:execute)
    described_class.run({ out_folder: "out" }, test: selected_test)
  end

  it "rejects a test outside the selected suite" do
    suite = described_class::TestSuite.new("Suite", output_dir: "out", input_dir: "test")
    other_suite = described_class::TestSuite.new("Other Suite", output_dir: "out", input_dir: "test")
    test = other_suite.test("Test") {}

    expect do
      described_class.run(suite: suite, test: test)
    end.to raise_error(ArgumentError, "test does not belong to the selected suite")
  end
end

RSpec.describe LatexTesting::Test do
  def create_test(directory, name: "manual check")
    File.write(File.join(directory, "fixture.tex"), "")
    test = described_class.new(name, output_dir: directory, input_dir: directory)
    test.file("fixture.tex")
    test.define_singleton_method(:build_raw) do |_source, temp_dir|
      File.write(File.join(temp_dir, "fixture.pdf"), "pdf")
      File.write(File.join(temp_dir, "fixture.log"), "log")
      true
    end
    test
  end

  it "reads the log and opens the PDF only once across assertions" do
    Dir.mktmpdir do |directory|
      File.write(File.join(directory, "fixture.tex"), "")
      test = described_class.new("cache check", output_dir: directory, input_dir: directory)
      test.file("fixture.tex")
      test.define_singleton_method(:build_raw) do |_source, temp_dir|
        File.write(File.join(temp_dir, "fixture.pdf"), "pdf")
        File.write(File.join(temp_dir, "fixture.log"), "log")
        true
      end

      document_class = Class.new do
        def self.open(_path)
          Object.new
        end
      end
      hexa_pdf = Module.new
      hexa_pdf.const_set(:Document, document_class)
      stub_const("HexaPDF", hexa_pdf)
      allow_any_instance_of(LatexTesting::Assertion::Execution)
        .to receive(:require).with("hexapdf")
      expect(document_class).to receive(:open)
        .with(File.join(directory, "cache check.pdf")).once.and_call_original
      expect(File).to receive(:read)
        .with(a_string_matching(/fixture\.log\z/)).once.and_call_original

      test.instance_eval do
        2.times do
          assert("reads cached resources") do
            log
            generated_pdf { pdf_path }
          end
        end
      end

      expect(test.execute).to be(true)
    end
  end

  it "marks manual assertions as skipped without prompting by default" do
    Dir.mktmpdir do |directory|
      test = create_test(directory)
      test.instance_eval { user_assert("The title is visible") }

      expect($stdin).not_to receive(:gets)
      expected_output =
        "    manual check - #{LatexTesting::YELLOW}1 MANUAL TESTS SKIPPED#{LatexTesting::RESET}\n"
      expect { expect(test.execute).to be(true) }
        .to output(expected_output).to_stdout
    end
  end

  it "counts skipped manual assertions in the test result" do
    Dir.mktmpdir do |directory|
      test = create_test(directory)
      test.instance_eval do
        user_assert("The title is visible")
        user_assert("The footer is visible")
      end
      expected_output =
        "    manual check - #{LatexTesting::YELLOW}2 MANUAL TESTS SKIPPED#{LatexTesting::RESET}\n"

      expect { expect(test.execute).to be(true) }
        .to output(expected_output).to_stdout
    end
  end

  it "fails a skipped manual assertion if the PDF was not copied" do
    Dir.mktmpdir do |directory|
      test = create_test(directory)
      test.instance_eval { user_assert("The title is visible") }
      allow(FileUtils).to receive(:cp)

      expect { expect(test.execute).to be(false) }
        .to output(/FAIL.*No PDF file produced by LaTeX build/)
        .to_stdout
    end
  end

  it "copies the PDF before prompting for a manual assertion" do
    Dir.mktmpdir do |directory|
      test = create_test(directory)
      test.instance_eval { user_assert("The title is visible") }
      output_pdf = File.join(directory, "manual check.pdf")
      allow($stdin).to receive(:gets) do
        expect(File.file?(output_pdf)).to be(true)
        "yes\n"
      end

      expected_output = [
        "    manual check - The title is visible",
        "PDF: #{output_pdf}",
        "Does this assertion pass? [yes/no] ",
        "#{LatexTesting::GREEN}PASSED#{LatexTesting::RESET}"
      ].join("\n") + "\n"

      expect { expect(LatexTesting.run({ user_interaction: true }, test: test)).to be(true) }
        .to output(expected_output)
        .to_stdout
    end
  end

  it "fails when a user rejects a manual assertion" do
    Dir.mktmpdir do |directory|
      test = create_test(directory)
      test.instance_eval { user_assert("The title is visible") }
      allow($stdin).to receive(:gets).and_return("no\n")

      expect { expect(test.execute(user_interaction: true)).to be(false) }
        .to output(/FAIL.*User assertion rejected: The title is visible/)
        .to_stdout
    end
  end

  it "accepts y as confirmation" do
    Dir.mktmpdir do |directory|
      test = create_test(directory)
      test.instance_eval { user_assert("The title is visible") }
      allow($stdin).to receive(:gets).and_return("y\n")

      expect { expect(test.execute(user_interaction: true)).to be(true) }
        .to output(/PASSED/).to_stdout
    end
  end

  it "rejects n as denial" do
    Dir.mktmpdir do |directory|
      test = create_test(directory)
      test.instance_eval { user_assert("The title is visible") }
      allow($stdin).to receive(:gets).and_return("n\n")

      expect { expect(test.execute(user_interaction: true)).to be(false) }
        .to output(/FAIL.*User assertion rejected: The title is visible/)
        .to_stdout
    end
  end

  it "retries invalid responses and accepts yes case-insensitively" do
    Dir.mktmpdir do |directory|
      test = create_test(directory)
      test.instance_eval { user_assert("The title is visible") }
      expect($stdin).to receive(:gets).twice.and_return("maybe\n", "YES\n")

      expect { expect(test.execute(user_interaction: true)).to be(true) }
        .to output(/PASS/).to_stdout
    end
  end

  it "does not mark tests without manual assertions as skipped" do
    Dir.mktmpdir do |directory|
      test = create_test(directory)

      expect($stdin).not_to receive(:gets)
      expect { expect(test.execute).to be(true) }
        .to output(/PASS/).to_stdout
    end
  end
end
