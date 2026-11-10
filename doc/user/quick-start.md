# Quick Start

[← User Guide](README.md)

LatexTesting runs test definitions in a host Ruby project. A definition file
and its LaTeX fixture are commonly kept together under the host's test
directory.

Create `test/unit/example/hello.tex`:

```tex
\documentclass{article}
\begin{document}
Hello, LaTeX!
\end{document}
```

Create `test/unit/example/tests.rb`:

```ruby
testsuite "Example" do
  test "Hello document has one page" do
    file "hello.tex"

    assert "the PDF has one page" do
      generated_pdf do
        fail "Expected one page, found #{pages.count}" unless pages.count == 1
      end
    end
  end
end
```

The fixture path is relative to `tests.rb`. The `assert` block can use
`generated_pdf` to inspect the compiled document through HexaPDF.

Run the definition with the host project's configured test command. See
[Running Tests](running-tests.md) for the public runner API.
