# Architecture

[← Developer Guide](README.md)

The framework separates definition, compilation, and assertion execution:

1. `LatexTesting` loads definition files and retains them for a later run.
2. `TestFile` collects tests declared directly in a file and named
   `TestSuite`s.
3. Each `TestSuite` collects `Test` objects in declaration order.
4. A `Test` selects one fixture, invokes the host's `build_raw` helper, and
   runs its assertions against the result.
5. Each `Assertion` evaluates its block in an `Assertion::Execution` context.
   One execution context is shared across all assertions in the test.
6. `generated_pdf` creates a `PDFExecution` wrapper around a HexaPDF document.
   The wrapper delegates calls to assertion helpers first and the document
   second.

The implementation is divided into small files under `lib/latextesting/`, one
for each class. The public entry point `lib/latextesting.rb` requires them and
sets up framework constants.

The framework does not select or invoke a LaTeX compiler itself. The host
application supplies `build_raw`; see [Build Lifecycle](build-lifecycle.md)
for the contract.
