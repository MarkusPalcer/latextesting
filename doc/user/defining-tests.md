# Defining Tests

[← User Guide](README.md)

LatexTesting discovers Ruby definition files alongside the LaTeX fixtures
they use. The common layout is a `tests.rb` file and one or more `.tex`
fixtures in each test directory.

A definition file can declare tests directly:

```ruby
test "A file-level test" do
  file "fixture.tex"
end
```

Or it can group related tests into named suites:

```ruby
testsuite "Diagnostics" do
  test "Reports a missing command" do
    file "missing-command.tex"
    expect_compilation_failure
    requires_log "Undefined control sequence"
  end
end
```

Tests declared directly in the file run before its named suites. Tests within
a suite run in declaration order. Reusing the same suite name adds tests to
that suite.

Definition files should use one of the recognized names: `*tests.rb`,
`*test.rb`, `test.rb`, or `tests.rb`. See [Running Tests](running-tests.md)
for how the runner finds these files.
