# Inspecting PDFs

[← User Guide](README.md)

Use `generated_pdf` when an assertion needs to inspect the PDF document:

```ruby
assert "the document has six pages" do
  generated_pdf do
    fail "Expected six pages, found #{pages.count}" unless pages.count == 6
  end
end
```

Inside the block, HexaPDF document methods such as `pages` are available along
with assertion helpers such as `fail`, `log`, and `pdf_path`. The block is
evaluated only after the fixture has been compiled. LatexTesting declares
HexaPDF as a runtime dependency and loads it when `generated_pdf` is first
used.

Use `pdf_path` directly if an assertion needs to pass the generated file to
another tool. The runner copies the PDF to the test's output directory before
assertions run, so the path remains available after the test completes.
