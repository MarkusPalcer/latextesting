# frozen_string_literal: true

require "latextesting"
require "hexapdf"

# Helpers for constructing synthetic pages for text-line assertions.
module PDFTextLineSpecHelpers
  def proxy_for(page)
    LatexTesting::Assertion::Execution::PDFExecution::Page.new(page)
  end

  def draw_text_runs(page)
    canvas = page.canvas.font("Helvetica", size: 12)
    canvas.text("Hello", at: [10, 100])
    canvas.text("world", at: [48, 100])
    canvas.text("second line", at: [10, 80])
  end
end

RSpec.describe "PDF text-line extraction" do
  include PDFTextLineSpecHelpers

  it "groups glyph runs into lines and reconstructs word spaces" do
    page = HexaPDF::Document.new.pages.add
    draw_text_runs(page)
    proxy = proxy_for(page)
    expect(page).to receive(:process_contents).once.and_call_original

    lines = proxy.text_lines

    expect(lines.map(&:text)).to eq(["Hello world", "second line"])
    expect(proxy.text_lines).to equal(lines)
    expect(lines.map(&:boundary)).to all(be_a(LatexTesting::Boundary))
    expect(lines.first.boundary.left).to eq(10)
    expect(lines.first.boundary.top).to be < lines.last.boundary.top
    expect(lines).to be_frozen
    expect(lines).to all(be_frozen)
  end
end

RSpec.describe "Empty PDF text lines" do
  include PDFTextLineSpecHelpers

  it "returns and caches an empty line collection for a blank page" do
    page = HexaPDF::Document.new.pages.add
    proxy = proxy_for(page)
    expect(page).to receive(:process_contents).once.and_call_original

    lines = proxy.text_lines

    expect(lines).to be_empty
    expect(lines).to equal(proxy.text_lines)
  end
end

RSpec.describe "PDF text-line coordinates" do
  include PDFTextLineSpecHelpers

  it "translates shifted MediaBox coordinates and converts all edges with UserUnit" do
    page = HexaPDF::Document.new.pages.add
    page[:MediaBox] = [10, 20, 210, 220]
    page[:UserUnit] = 2
    page.canvas(translate_origin: false).font("Helvetica", size: 12).text("A", at: [30, 180])
    proxy = proxy_for(page)

    boundary = proxy.text_lines.fetch(0).boundary
    converted = proxy.convert_unit(boundary, LatexTesting::TargetUnit::MILLIMETERS)
    expected_edges = [20, 28.828, 28.004, 42.7]
    actual_edges = [boundary.left, boundary.top, boundary.right, boundary.bottom]

    actual_edges.zip(expected_edges).each do |actual, expected|
      expect(actual).to be_within(0.001).of(expected)
    end
    [converted.left, converted.top, converted.right, converted.bottom].zip(expected_edges).each do |actual, expected|
      expected_mm = proxy.convert_unit(expected, LatexTesting::TargetUnit::MILLIMETERS)
      expect(actual).to be_within(0.001).of(expected_mm)
    end
  end
end

RSpec.describe "Invalid PDF text-line unit conversions" do
  include PDFTextLineSpecHelpers

  it "rejects values that are neither numeric nor boundaries" do
    proxy = proxy_for(HexaPDF::Document.new.pages.add)

    expect { proxy.convert_unit("72", LatexTesting::TargetUnit::MILLIMETERS) }
      .to raise_error(ArgumentError, /must be numeric/)
  end
end
