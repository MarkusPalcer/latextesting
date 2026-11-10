# Runner and Discovery

[← Developer Guide](README.md)

The `LatexTesting` module caches parsed definition files by expanded filename
to avoid evaluating declarations twice. The cached paths are loader state only;
tests are registered globally by fixture name.

- `parse_file(filename)` returns a cached list of fixtures when a path has
  already been parsed. Otherwise it evaluates declarations in a
  `DefinitionContext`. If evaluation raises, fixtures registered from that
  file are removed and the error propagates.
- `scan(base_dir)` searches recursively for `*tests.rb`, `*test.rb`, `test.rb`,
  and `tests.rb`. It de-duplicates and sorts the paths before parsing them, then
  returns their fixtures in declaration order. Fixture names must be globally
  unique, including across definition files.
- `run(options = {}, fixture: nil, test: nil, **run_options)` executes all
  registered fixtures unless a fixture or one of its tests is selected. A
  fixture is compiled once per invocation; selecting one test still builds
  that test's fixture. If both selectors are supplied, the test must belong to
  the fixture. The cache is not cleared and individual results are not
  aggregated into a process status. If `options[:junit_report]` is set to a
  filename, the run overwrites it with JUnit XML containing selected tests.
  JUnit's required `<testsuite>` element represents a fixture, not a framework
  suite. Failed tests receive `<failure>` elements; skipped manual tests count
  as passing cases.

Execution order is stable: files are parsed by sorted path, fixtures are
registered in declaration order, and tests run in declaration order. A
fixture-level build failure (including an unexpected result for
`expect_compilation_failure`) marks all selected tests in that fixture as
failed. A failed test does not stop later tests from running.
