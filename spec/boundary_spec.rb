# frozen_string_literal: true

require "latextesting"

RSpec.describe LatexTesting::Boundary do
  it "constructs boundaries from edges or dimensions using top-left coordinates" do
    title = described_class.new(left: 5, top: 5, height: 15, right: 143)
    content = described_class.new(left: 5, top: 22, right: 143, bottom: 100)
    dimensioned = described_class.new(left: 5, bottom: 20, width: 10, height: 4)

    expect([title.left, title.top, title.right, title.bottom]).to eq([5, 5, 143, 20])
    expect([content.top, content.bottom]).to eq([22, 100])
    expect([content.width, content.height]).to eq([138, 78])
    expect([dimensioned.left, dimensioned.top, dimensioned.right, dimensioned.bottom])
      .to eq([5, 16, 15, 20])
  end

  it "is immutable" do
    boundary = described_class.new(left: 0, top: 0, right: 10, bottom: 10)

    expect { boundary.left = 1 }.to raise_error(FrozenError)
  end
end

RSpec.describe "Inclusive boundary matching" do
  include RSpec::Matchers
  include LatexTesting::BoundaryMatchers

  let(:containing_boundary) do
    LatexTesting::Boundary.new(left: 5, top: 10, right: 15, bottom: 20)
  end

  it "accepts identical boundaries and inclusive contact at every edge" do
    expect(containing_boundary).to be_within(containing_boundary)

    [
      { left: 5, top: 12, right: 13, bottom: 18 },
      { left: 7, top: 10, right: 13, bottom: 18 },
      { left: 7, top: 12, right: 15, bottom: 18 },
      { left: 7, top: 12, right: 13, bottom: 20 }
    ].each do |edges|
      expect(LatexTesting::Boundary.new(**edges)).to be_within(containing_boundary)
    end
  end
end

RSpec.describe "Boundary matcher failures" do
  include RSpec::Matchers
  include LatexTesting::BoundaryMatchers

  let(:containing_boundary) { LatexTesting::Boundary.new(left: 5, top: 10, right: 15, bottom: 20) }

  it "rejects an overrun on each side and reports both boundaries" do
    [
      { left: 4, top: 12, right: 13, bottom: 18 },
      { left: 7, top: 9, right: 13, bottom: 18 },
      { left: 7, top: 12, right: 16, bottom: 18 },
      { left: 7, top: 12, right: 13, bottom: 21 }
    ].each do |edges|
      actual = LatexTesting::Boundary.new(**edges)
      expect do
        expect(actual).to be_within(containing_boundary)
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError,
                         /#{actual.inspect}.*#{containing_boundary.inspect}/)
    end
  end

  it "reports a non-boundary actual without attempting geometric comparisons" do
    expect { expect(nil).to be_within(containing_boundary) }
      .to raise_error(RSpec::Expectations::ExpectationNotMetError, /expected nil to be within/)
  end

  it "retains the negated failure message" do
    expect { expect(containing_boundary).not_to be_within(containing_boundary) }
      .to raise_error(RSpec::Expectations::ExpectationNotMetError, /not to be within/)
  end
end

RSpec.shared_context "boundary diagnostics" do
  include RSpec::Matchers
  include LatexTesting::BoundaryMatchers

  let(:containing_boundary) { LatexTesting::Boundary.new(left: 5, top: 10, right: 15, bottom: 20) }
end

RSpec.describe "Boundary matcher edge diagnostics" do
  include_context "boundary diagnostics"

  it "identifies each violated edge with its actual and expected values" do
    cases = [
      [{ left: 4, top: 12, right: 13, bottom: 18 }, "left (actual.left=4 < expected.left=5)"],
      [{ left: 7, top: 9, right: 13, bottom: 18 }, "top (actual.top=9 < expected.top=10)"],
      [{ left: 7, top: 12, right: 16, bottom: 18 }, "right (actual.right=16 > expected.right=15)"],
      [{ left: 7, top: 12, right: 13, bottom: 21 }, "bottom (actual.bottom=21 > expected.bottom=20)"]
    ]

    cases.each do |edges, detail|
      actual = LatexTesting::Boundary.new(**edges)
      message = "actual extends beyond expected: #{detail}"
      expect { expect(actual).to be_within(containing_boundary) }
        .to raise_error(RSpec::Expectations::ExpectationNotMetError, /#{Regexp.escape(message)}/)
    end
  end
end

RSpec.describe "Boundary matcher multiple edge diagnostics" do
  include_context "boundary diagnostics"

  it "reports all violated edges when the actual boundary surrounds the expected boundary" do
    actual = LatexTesting::Boundary.new(left: 4, top: 9, right: 16, bottom: 21)
    details = ["left (actual.left=4 < expected.left=5)", "top (actual.top=9 < expected.top=10)",
               "right (actual.right=16 > expected.right=15)", "bottom (actual.bottom=21 > expected.bottom=20)"]
    message = "actual extends beyond expected: #{details.join(", ")}"

    expect { expect(actual).to be_within(containing_boundary) }
      .to raise_error(RSpec::Expectations::ExpectationNotMetError, /#{Regexp.escape(message)}/)
  end

  it "treats touching boundaries as overrun rather than complete separation" do
    actual = LatexTesting::Boundary.new(left: 1, top: 12, right: 5, bottom: 18)
    message = "actual extends beyond expected: left (actual.left=1 < expected.left=5)"

    expect { expect(actual).to be_within(containing_boundary) }
      .to raise_error(RSpec::Expectations::ExpectationNotMetError, /#{Regexp.escape(message)}/)
  end
end

RSpec.describe "Boundary matcher separation diagnostics" do
  include_context "boundary diagnostics"

  it "reports the direction and facing edges for completely separated boundaries" do
    cases = [
      [{ left: 1, top: 12, right: 4, bottom: 18 }, "left of expected (actual.right=4 < expected.left=5)"],
      [{ left: 16, top: 12, right: 19, bottom: 18 }, "right of expected (actual.left=16 > expected.right=15)"],
      [{ left: 7, top: 6, right: 13, bottom: 9 }, "above expected (actual.bottom=9 < expected.top=10)"],
      [{ left: 7, top: 21, right: 13, bottom: 24 }, "below expected (actual.top=21 > expected.bottom=20)"]
    ]

    cases.each do |edges, detail|
      actual = LatexTesting::Boundary.new(**edges)
      message = "actual is completely outside expected: #{detail}"
      expect { expect(actual).to be_within(containing_boundary) }
        .to raise_error(RSpec::Expectations::ExpectationNotMetError, /#{Regexp.escape(message)}/)
    end
  end
end

RSpec.describe "Boundary matcher diagonal separation diagnostics" do
  include_context "boundary diagnostics"

  it "reports both directions for diagonal separation" do
    actual = LatexTesting::Boundary.new(left: 1, top: 6, right: 4, bottom: 9)
    details = "left of expected (actual.right=4 < expected.left=5), above expected (actual.bottom=9 < expected.top=10)"
    message = "actual is completely outside expected: #{details}"

    expect { expect(actual).to be_within(containing_boundary) }
      .to raise_error(RSpec::Expectations::ExpectationNotMetError, /#{Regexp.escape(message)}/)
  end

  it "prefers separation diagnostics when the other axis also overruns" do
    actual = LatexTesting::Boundary.new(left: 1, top: 9, right: 4, bottom: 21)
    message = "actual is completely outside expected: left of expected (actual.right=4 < expected.left=5)"

    expect { expect(actual).to be_within(containing_boundary) }
      .to raise_error(RSpec::Expectations::ExpectationNotMetError, /#{Regexp.escape(message)}/)
  end
end

RSpec.describe "Boundary matcher with a custom assertion message" do
  include_context "boundary diagnostics"

  it "preserves the diagnostic alongside the context" do
    actual = LatexTesting::Boundary.new(left: 4, top: 12, right: 13, bottom: 18)
    matcher = be_within(containing_boundary)

    expect { expect(actual).to matcher, -> { "line text: #{matcher.failure_message}" } }
      .to raise_error(RSpec::Expectations::ExpectationNotMetError,
                      /line text: actual extends beyond expected: left \(actual\.left=4 < expected\.left=5\)/)
  end
end

RSpec.describe "Numeric boundary matcher compatibility" do
  include RSpec::Matchers
  include LatexTesting::BoundaryMatchers

  it "leaves RSpec's numeric be_within matcher unchanged" do
    expect(0.5).to be_within(0.01).of(0.5)
    expect(0.5).not_to be_within(0.01).of(0.6)
  end
end

RSpec.describe LatexTesting::Assertion::Execution do
  it "exposes the boundary matcher while preserving numeric RSpec matchers" do
    execution = described_class.allocate
    boundary = LatexTesting::Boundary.new(left: 0, top: 0, right: 10, bottom: 10)

    expect(execution.be_within(boundary).matches?(boundary)).to be(true)
    expect(execution.be_within(0.01).of(0.5).matches?(0.5)).to be(true)
  end
end
