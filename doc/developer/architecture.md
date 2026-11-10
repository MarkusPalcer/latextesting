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
   second. Its page collection returns page proxies that delegate to HexaPDF;
   the proxies lazily cache MediaBox boundaries and parsed frame collections.

The implementation is divided into small files under `lib/latextesting/`, one
for each class. The public entry point `lib/latextesting.rb` requires the
framework classes and sets up constants; the content processor and frame
extractor load lazily when a page's `frames` are first requested.

Frame extraction uses a HexaPDF content processor to track stroke paths and
graphics state, then groups only supported rectangular outlines. Unit
conversion is provided by the page proxy and accounts for the page's
`/UserUnit`; the assertion test supplies the target-unit constant.

The framework does not select or invoke a LaTeX compiler itself. The host
application supplies `build_raw`; see [Build Lifecycle](build-lifecycle.md)
for the contract.
