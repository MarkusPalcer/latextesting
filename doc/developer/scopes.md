# Scopes and Evaluation

[← Developer Guide](README.md)

The DSL changes `self` as it moves from definition to execution. This table
shows the objects that receive each block:

| Block | Receiver |
|---|---|
| Definition file source | `LatexTesting::DefinitionContext` |
| `fixture` block | `LatexTesting::Fixture` |
| `test` block | `LatexTesting::Assertion::Execution` |
| `generated_pdf` block | `LatexTesting::Assertion::Execution::PDFExecution` |

`LatexTesting.parse_file` evaluates source with
`DefinitionContext#instance_eval`. Fixture declaration blocks use
`instance_eval` to configure the `.tex` input and define named tests. Tests use
`instance_exec` so their blocks run with the shared test execution context
while retaining captured local variables. `manual_test` and `requires_log`
declare named tests on the fixture.

The PDF wrapper implements `method_missing` and `respond_to_missing?`. It
forwards public methods to the assertion execution object when available, and
otherwise to the HexaPDF document. This lets one test block use PDF operations
and test helpers without introducing a second DSL.

Resource state lives on `Assertion::Execution`. `Fixture#execute` creates one
execution context for a compiled fixture and passes it to each named test.
The log string and PDF wrapper are initialized lazily and cached there, so
they are shared across tests within that fixture, but not across fixtures.
