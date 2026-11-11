# Defining Tests

[← User Guide](README.md)

LatexTesting discovers Ruby definition files alongside the LaTeX fixtures
they use. The common layout is a `tests.rb` file and one or more `.tex`
fixtures in each test directory.

A definition file declares named fixtures. Fixture names must be unique
across all discovered definition files. Each fixture selects one `.tex` file
and contains named tests; test names must be unique within that fixture. A
fixture is compiled once, then each test checks one fact about its output:

```ruby
fixture "Hello document" do
  file "fixture.tex"

  test "The PDF has one page" do
    expect(generated_pdf.pages.count).to eq(1)
  end

  manual_test "The title is visible on the page."
end
```

`requires_log` defines a named test that checks the build log. Use
`expect_compilation_failure` on the fixture when the `.tex` file is expected to
fail:

```ruby
fixture "Missing command diagnostic" do
  file "missing-command.tex"
  expect_compilation_failure
  requires_log "Undefined control sequence"
end
```

Definition files are only declaration sources; they do not create an implicit
suite or group the tests. Tests run in declaration order, and a failed test
does not prevent later tests for the same fixture from running.

Definition files should use one of the recognized names: `*tests.rb`,
`*test.rb`, `test.rb`, or `tests.rb`. See [Running Tests](running-tests.md)
for how the runner finds these files.
