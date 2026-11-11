# frozen_string_literal: true

require "latextesting"
require "hexapdf"

module PDFAssertionSpecHelpers
  FRAME_MUTANT_SUBJECTS = [
    "LatexTesting::Assertion::Execution::PDFExecution::Page#frames",
    "LatexTesting::Assertion::Execution::PDFExecution::Page#extract_frames",
    "LatexTesting::Assertion::Execution::PDFExecution::FrameExtractor*",
    "LatexTesting::Assertion::Execution::PDFExecution::FramePartitioner*",
    "LatexTesting::Assertion::Execution::PDFExecution::FrameGeometry*",
    "LatexTesting::Assertion::Execution::PDFExecution::FrameCollection*",
    "LatexTesting::Assertion::Execution::PDFExecution::Frame*",
    "LatexTesting::Assertion::Execution::PDFExecution::FrameProcessor*"
  ].freeze

  def draw_frame(page, bounds, color: [0.75, 0, 0], width: 2, cap: :butt)
    canvas = page.canvas
    canvas.stroke_color(*color).line_width(width).line_cap_style(cap)
    frame_segments(bounds, width).each do |x1, y1, x2, y2|
      canvas.move_to(x1, y1).line_to(x2, y2).stroke
    end
  end

  def frame_segments(bounds, width)
    left, bottom, right, top = bounds
    half_width = width / 2.0
    left_center = left + half_width
    right_center = right - half_width
    bottom_center = bottom + half_width
    top_center = top - half_width
    [[left, bottom_center, right, bottom_center],
     [right_center, bottom_center, right_center, top_center],
     [right, top_center, left, top_center],
     [left_center, top_center, left_center, bottom_center]]
  end

  def proxy_for(page)
    LatexTesting::Assertion::Execution::PDFExecution::Page.new(page)
  end
end

RSpec.describe LatexTesting::Assertion::Execution::PDFExecution::PageCollection do
  it "delegates page collection operations and wraps page results" do
    collection = described_class.new(HexaPDF::Document.new.pages)

    expect(collection.add).to be_a(LatexTesting::Assertion::Execution::PDFExecution::Page)
    expect(collection[0]).to be_a(LatexTesting::Assertion::Execution::PDFExecution::Page)
    expect(collection.count).to eq(1)
    expect(collection.first.box(:media).width).to be_positive
    expect(collection.each_with_index.map { |_page, index| index }).to eq([0])
  end
end

RSpec.describe LatexTesting::Assertion::Execution::PDFExecution::Page do
  it "uses MediaBox boundaries and applies UserUnit during conversion" do
    page = HexaPDF::Document.new.pages.add
    page[:MediaBox] = [10, 20, 610, 820]
    page[:UserUnit] = 2
    proxy = described_class.new(page)

    expect([proxy.boundary.left, proxy.boundary.bottom, proxy.boundary.right, proxy.boundary.top])
      .to eq([10, 20, 610, 820])
    expect([proxy.boundary.width, proxy.boundary.height]).to eq([600, 800])
    expect(proxy.convert_unit(72, LatexTesting::TargetUnit::MILLIMETERS)).to eq(50.8)
  end
end

RSpec.describe "PDF frame extraction" do
  include PDFAssertionSpecHelpers

  it "extracts immutable frames with visible bounds and caches them",
     mutant_expression: PDFAssertionSpecHelpers::FRAME_MUTANT_SUBJECTS do
    page = HexaPDF::Document.new.pages.add
    draw_frame(page, [10, 20, 90, 100])
    proxy = proxy_for(page)
    expect(page).to receive(:contents).once.and_call_original
    expect(proxy).to receive(:require).with("hexapdf").and_return(true)
    expect(proxy).to receive(:require_relative).with("pdf_frame_processor").and_return(true)
    expect(proxy).to receive(:require_relative).with("pdf_frame_extractor").and_return(true)

    frames = proxy.frames
    frame = frames.single { |candidate| candidate.color == [0.75, 0, 0] }

    expect(proxy.frames).to equal(frames)
    expect(frames.find { |candidate| candidate.color == [0.75, 0, 0] }).to equal(frame)
    expect(frame.color.color_space).to eq(:DeviceRGB)
    expect(frame.color.components).to eq([0.75, 0, 0])
    expect([frame.left, frame.bottom, frame.right, frame.top]).to eq([10, 20, 90, 100])
    expect(frame.stroke_width).to eq(2)
    expect(frame.width).to eq(80)
    expect(frame.height).to eq(80)
    expect { frame.left = 0 }.to raise_error(NoMethodError)
    expect { frame.color << 1 }.to raise_error(FrozenError)
  end
end

RSpec.describe "PDF frame matching" do
  include PDFAssertionSpecHelpers

  it "recognizes multiple same-color frames and requires unique single matches",
     mutant_expression: [
       "LatexTesting::Assertion::Execution::PDFExecution::FrameCollection*",
       "LatexTesting::Assertion::Execution::PDFExecution::FrameExtractor*",
       "LatexTesting::Assertion::Execution::PDFExecution::FramePartitioner*",
       "LatexTesting::Assertion::Execution::PDFExecution::FrameGeometry*"
     ] do
    page = HexaPDF::Document.new.pages.add
    draw_frame(page, [10, 10, 30, 30])
    draw_frame(page, [50, 50, 80, 80])
    frames = proxy_for(page).frames

    expect(frames.count).to eq(2)
    expect(frames.map(&:left)).to eq([10, 50])
    expect { frames.single { |frame| frame.color == [0.75, 0, 0] } }
      .to raise_error(/found 2/)
    expect { frames.single { |frame| frame.color == [0, 0, 0] } }
      .to raise_error(/found none/)
  end
end

RSpec.describe "Ambiguous PDF frame geometry" do
  include PDFAssertionSpecHelpers

  it "rejects strokes that can be partitioned into frames in multiple ways",
     mutant_expression: [
       "LatexTesting::Assertion::Execution::PDFExecution::Page#frames",
       "LatexTesting::Assertion::Execution::PDFExecution::Page#extract_frames",
       "LatexTesting::Assertion::Execution::PDFExecution::FrameExtractor*",
       "LatexTesting::Assertion::Execution::PDFExecution::FramePartitioner*",
       "LatexTesting::Assertion::Execution::PDFExecution::FrameGeometry*",
       "LatexTesting::Assertion::Execution::PDFExecution::FrameProcessor*"
     ] do
    page = HexaPDF::Document.new.pages.add
    2.times { draw_frame(page, [10, 10, 30, 30]) }

    expect { proxy_for(page).frames }
      .to raise_error(/Ambiguous frame geometry/)
  end
end

RSpec.describe "Unsupported PDF frame geometry" do
  include PDFAssertionSpecHelpers

  it "rejects curved, transformed, and non-butt strokes",
     mutant_expression: [
       "LatexTesting::Assertion::Execution::PDFExecution::Page#extract_frames",
       "LatexTesting::Assertion::Execution::PDFExecution::FrameExtractor*",
       "LatexTesting::Assertion::Execution::PDFExecution::FrameProcessor*"
     ] do
    curved_page = HexaPDF::Document.new.pages.add
    curved_page.canvas.move_to(0, 0).curve_to(10, 0, p1: [3, 5], p2: [7, 5]).stroke
    expect { proxy_for(curved_page).frames }.to raise_error(/Unsupported frame path/)

    capped_page = HexaPDF::Document.new.pages.add
    draw_frame(capped_page, [10, 10, 30, 30], cap: :round)
    expect { proxy_for(capped_page).frames }.to raise_error(/only butt line caps/)

    scaled_page = HexaPDF::Document.new.pages.add
    scaled_page.canvas.transform(2, 0, 0, 1, 0, 0).move_to(0, 0).line_to(10, 0).stroke
    expect { proxy_for(scaled_page).frames }.to raise_error(/Unsupported frame path/)
  end
end
