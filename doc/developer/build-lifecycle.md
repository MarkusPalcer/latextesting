# Build Lifecycle

[← Developer Guide](README.md)

For each configured `Test`, the framework:

1. Verifies a fixture was selected and exists.
2. Creates a temporary directory.
3. Calls the host's `build_raw(source_path, temporary_output_directory)`.
4. Checks the helper's return value against `expect_compilation_failure`.
5. Copies or records build artifacts, then runs assertions in order.
6. Removes the temporary directory when execution leaves the block.

The host helper must return a truthy value for a successful compilation and
place the fixture's PDF and log in the supplied directory. `Test#run` checks
that a successful build actually produced a PDF. A failed build saves its log
in the test output directory; if there is no log, the exception and backtrace
are saved instead.

Successful PDFs are copied to the output directory using the test name. The
directory hierarchy is derived from the definition file and, for named
suites, the suite name. The output root is `out/` under the current project
directory.

`Test#execute` catches `StandardError`, prints `PASS`, `PASSED`, `FAIL`, or
`<count> MANUAL TESTS SKIPPED` in yellow, and returns a Boolean. A skipped
manual assertion counts as a passing test; a test without manual assertions is
never marked skipped. A failure stops the remaining assertions in that test.

The PDF is copied to the test's persistent output path before assertions run.
`pdf_path` and `generated_pdf` use that copied file, while `log` reads the
temporary build log. A `user_assert` declaration is skipped by default. When
`LatexTesting.run` receives `user_interaction: true`, it shows the assertion
and persistent PDF path and accepts `yes`/`y` or `no`/`n`; acceptance prints
`PASSED` and a rejection fails the test. Even when skipped, `user_assert` verifies that the
persistent PDF exists; a missing PDF fails the test.
Higher-level `TestSuite`, `TestFile`, and module-level execution do not
aggregate individual Boolean results into the process exit status.
