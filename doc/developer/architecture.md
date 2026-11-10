# Architecture

[← Developer Guide](README.md)

The framework separates definition loading, fixture compilation, and test
execution:

1. `LatexTesting` loads definition files as declaration sources and registers
   globally unique `Fixture` objects. Definition files and suites are not
   execution units.
2. A `Fixture` selects one `.tex` source and owns named `Test` objects. Test
   names are unique within the fixture.
3. The host's `build_raw` helper compiles a fixture once. Each test then
   evaluates its block independently in the fixture's shared
   `Assertion::Execution` context, so one failed test does not skip later
   tests.
4. A fixture-level build failure or an unexpected build result fails all tests
   selected from that fixture.
5. `generated_pdf` creates a `PDFExecution` wrapper around a HexaPDF document.
   The wrapper delegates calls to test helpers first and the document
   second. Its page collection returns page proxies that delegate to HexaPDF;
   the proxies lazily cache MediaBox boundaries and parsed frame collections.

The implementation is divided into small files under `lib/latextesting/`.
`DefinitionContext` supplies the definition file's relative path for fixture
inputs and output locations without making the file an execution unit. The
public entry point `lib/latextesting.rb` requires the framework classes and
sets up constants; the content processor and frame extractor load lazily when
a page's `frames` are first requested.

Frame extraction uses a HexaPDF content processor to track stroke paths and
graphics state, then groups only supported rectangular outlines. Unit
conversion is provided by the page proxy and accounts for the page's
`/UserUnit`; the test uses the target-unit constant.

The framework does not select or invoke a LaTeX compiler itself. The host
application supplies `build_raw`; see [Build Lifecycle](build-lifecycle.md)
for the contract.
