# Quick Start

[← User Guide](README.md)

LatexTesting runs test definitions in a host Ruby project. A definition file
and its LaTeX fixtures are commonly kept together under the host's test
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
fixture "Hello document" do
  file "hello.tex"

  test "The PDF has one page" do
    expect(generated_pdf.pages.count).to eq(1)
  end
end
```

The `.tex` path is relative to `tests.rb`. The named test block can use
`generated_pdf` to inspect the compiled document through HexaPDF. Each
definition file may declare many fixtures; their names must be unique across
the project.

Run the definition with the host project's configured test command. See
[Running Tests](running-tests.md) for the public runner API.
