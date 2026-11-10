# Runner and Discovery

[← Developer Guide](README.md)

The `LatexTesting` module keeps a hash of parsed `TestFile` objects keyed by
expanded filename.

- `parse_file(filename)` returns a cached object when a path has already been
  parsed. Otherwise it registers a new object before evaluating the file,
  which prevents duplicate registration during recursive loads. If evaluation
  raises, the path is removed from the cache and the error propagates.
- `scan(base_dir)` searches recursively for `*tests.rb`, `*test.rb`, `test.rb`,
  and `tests.rb`. It de-duplicates and sorts the paths before parsing them, then
  returns the nonempty suites found in those files.
- `run(options = {}, suite: nil, test: nil, **run_options)` executes every
  cached definition file unless a suite or test selected from the scan result
  is supplied. When both selectors are supplied, the test must belong to that
  suite. The cache is not cleared and individual results are not aggregated
  into a process status. If `options[:junit_report]` is set to a filename, the
  run overwrites that file with JUnit XML for the tests selected by this
  invocation. Failed tests receive `<failure>` elements; skipped manual
  assertions are represented as passing test cases.

The execution order is stable: files are parsed by sorted path; within a file,
the implicit file-level suite runs before named suites; suites and tests run
in declaration order. A selected suite runs its tests in declaration order;
a selected test runs by itself.
