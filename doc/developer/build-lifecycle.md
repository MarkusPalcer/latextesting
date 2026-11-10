# Build Lifecycle

[← Developer Guide](README.md)

For each configured `Fixture`, the framework:

1. Verifies that a `.tex` file was selected and exists.
2. Creates a temporary directory.
3. Calls the host's `build_raw(source_path, temporary_output_directory)`.
4. Checks the helper's return value against the fixture's
   `expect_compilation_failure` setting.
5. Copies or records build artifacts, then runs every named test in order.
   Each test is reported independently, and a failure does not stop later
   tests from running.
6. Removes the temporary directory when fixture execution leaves the block.

The host helper must return a truthy value for a successful compilation and
place the fixture's PDF and log in the supplied directory. `Fixture#build`
checks that a successful build actually produced a PDF. A failed build saves
its log in the fixture output directory.

Successful PDFs are copied once per fixture. The directory hierarchy is
derived from the definition file and fixture name. The output root is `out/`
under the current project directory.

`Test#execute` catches `StandardError`, prints `PASS`, `PASSED`,
`MANUAL TEST SKIPPED`, or `FAIL`, and returns a Boolean. A skipped manual test
counts as a passing test in JUnit. A fixture-level build failure or unexpected
build result marks each selected test failed and prevents test blocks from
running.

The PDF is copied to the fixture's persistent output path before tests run.
`pdf_path` and `generated_pdf` use that copied file, while `log` reads the
temporary build log. A `manual_test` is skipped by default. When
`LatexTesting.run` receives `user_interaction: true`, it shows the test
description and persistent PDF path and accepts `yes`/`y` or `no`/`n`;
acceptance prints `PASSED` and rejection fails the test. Even when skipped,
`manual_test` verifies that the persistent PDF exists; a missing PDF fails
that test. The module-level runner does not aggregate individual Boolean
results into the process exit status.
