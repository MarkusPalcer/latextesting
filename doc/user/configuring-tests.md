# Configuring Fixtures

[← User Guide](README.md)

Each `fixture` block selects one `.tex` input and sets its expected compilation
result. Use these methods in the block:

| Method | Behavior |
|---|---|
| `file(filename)` | Selects a `.tex` file relative to the definition file. |
| `expect_compilation_failure` | Marks compilation failure as the expected outcome. |
| `test(name) { ... }` | Adds a named automated test to run after compilation. |
| `manual_test(description)` | Adds a named manual visual test. |
| `requires_log(substring)` | Adds a named test checking that the compiler log includes a substring. |

Fixture names must be unique across definition files. Test names must be
unique within a fixture. Select an existing `.tex` file with `file` before
adding tests. A fixture fails if compilation fails unexpectedly or succeeds
when `expect_compilation_failure` was set. `expect_compilation_failure` only
checks the build outcome; pair it with `requires_log` or a custom test to
check that the intended diagnostic was produced.

Tests run after either an expected successful build or an expected failed
build, so negative tests can inspect the failure log. They run in declaration
order; one failed test does not stop later tests. A fixture-level build failure
or unexpected build result fails all tests selected from that fixture.
