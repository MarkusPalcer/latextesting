# Development and Specs

[← Developer Guide](README.md)

The gem's RSpec suite tests the framework itself; it is separate from the
LaTeX fixture tests run by a host project.

From the LatexTesting repository root, install the gem's development
dependencies and run the specs:

```sh
bundle install
bundle exec rspec
```

The gemspec declares `hexapdf` as a runtime dependency. The framework requires
it lazily when `generated_pdf` is first used.
