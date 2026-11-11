# Inspecting PDFs

[← User Guide](README.md)

Use `generated_pdf` when a test needs to inspect the PDF document:

```ruby
test "The document has six pages" do
  expect(generated_pdf.pages.count).to eq(6)
end
```

`generated_pdf` returns the PDF document wrapper, which exposes HexaPDF document
methods such as `pages` along with test helpers such as `fail`, `log`, and
`pdf_path`. It is available only after the fixture has been compiled.
LatexTesting declares HexaPDF as a runtime dependency and loads it when
`generated_pdf` is first used.

`pages` is a collection proxy: indexing and enumeration return page proxies
that forward HexaPDF page methods and add:

- `page.boundary` — the page's MediaBox bounds (`left`, `bottom`, `right`,
  `top`, `width`, and `height`) in PDF user-space units.
- `page.frames` — a lazily parsed and cached enumerable of recognized colored
  rectangular frames.
- `page.convert_unit(value, target_unit)` — converts a PDF user-space
  measurement, applying the page's `/UserUnit`. Use
  `LatexTesting::TargetUnit::MILLIMETERS` for millimeters.

Frames expose `color`, `stroke_width`, and the `left`, `bottom`, `right`, and
`top` edges, including half the stroke width. The color compares to its
normalized components as an array and also exposes `color_space` and
`components`. For a required unique match, use `single` with a predicate:

```ruby
test "The header is 5 mm from the top of page 1" do
  page = generated_pdf.pages[0]
  header = page.frames.single { |frame| frame.color == [0.75, 0, 0] }
  top_margin = page.boundary.top - header[:top]
  margin_mm = page.convert_unit(top_margin, LatexTesting::TargetUnit::MILLIMETERS)
  expect(margin_mm).to be_within(0.01).of(5)
end
```

`frames` also supports normal enumeration and filtering. `single` fails if
there are zero or multiple matches rather than silently choosing one. Frame
recognition currently supports four straight, axis-aligned line strokes with
butt caps, consistent widths, and no scaling or rotation. Unsupported or
ambiguous stroke geometry fails explicitly; the API does not claim that PDF
content streams contain semantic frame objects.

Use `pdf_path` directly if a test needs to pass the generated file to another
tool. The runner copies the PDF to the fixture's output directory before its
tests run, so the path remains available after the test completes.
