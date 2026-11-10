# Scopes and Evaluation

[← Developer Guide](README.md)

The DSL changes `self` as it moves from definition to execution. This table
shows the objects that receive each block:

| Block | Receiver |
|---|---|
| Definition file source | `LatexTesting::TestFile` |
| `testsuite` block | `LatexTesting::TestSuite` |
| `test` block | `LatexTesting::Test` |
| `assert` block | `LatexTesting::Assertion::Execution` |
| `generated_pdf` block | `LatexTesting::Assertion::Execution::PDFExecution` |

`LatexTesting.parse_file` evaluates source with `TestFile#instance_eval`.
Suite and test configuration blocks are also evaluated with `instance_eval`.
Assertions use `instance_exec` so the block can be run with an execution
context while retaining captured local variables.

The PDF wrapper implements `method_missing` and `respond_to_missing?`. It
forwards public methods to the assertion execution object when available, and
otherwise to the HexaPDF document. This lets one block use PDF operations and
assertion helpers without introducing a second DSL.

Resource state lives on `Assertion::Execution`. `Test#execute` creates one
execution context for the test and passes it to each assertion. The log string
and PDF wrapper are initialized lazily and cached there, so they are shared
across assertions but not across tests.
