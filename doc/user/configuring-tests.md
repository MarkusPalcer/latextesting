# Configuring Tests

[← User Guide](README.md)

Each `test` block configures one fixture and its expected compilation result.
Use these methods in the block:

| Method | Behavior |
|---|---|
| `file(filename)` | Selects a fixture relative to the definition file. |
| `expect_compilation_failure` | Marks compilation failure as the expected outcome. |
| `requires_log(substring)` | Checks that the compiler log includes a substring. |
| `assert(name = nil) { ... }` | Adds a custom check to run after compilation. |

Select an existing fixture with `file` before adding assertions. A test fails
if compilation fails unexpectedly or succeeds when `expect_compilation_failure`
was set. `expect_compilation_failure` only checks whether compilation failed;
pair it with `requires_log` or a custom assertion to check that the intended
diagnostic was produced.

Assertions run after either an expected successful build or an expected failed
build, so negative tests can inspect the failure log. They run in declaration
order; if one fails, later assertions in that test are not run.
