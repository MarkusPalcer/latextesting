# Development and Specs

[← Developer Guide](README.md)

The gem's RSpec suite tests the framework itself; it is separate from the
LaTeX fixture tests run by a host project.
Temporary data created by gem specs must stay under `/tmp`, not in the
repository checkout. The RSpec setup forces `TMPDIR` to `/tmp`; use
`Dir.mktmpdir` without passing the repository path as its parent.

From the LatexTesting repository root, install the gem's development
dependencies and run the specs:

```sh
bundle install
bundle exec rspec
```

The gemspec declares `hexapdf` as a runtime dependency. The framework requires
it lazily when `generated_pdf` is first used.

Run mutation testing separately with:

```sh
bundle exec rake mutant
```

Mutant and its RSpec integration are development-only dependencies. The
`.mutant.yml` configuration loads the `LatexTesting` library and selects its
subjects for mutation testing; the task uses Mutant's open-source mode.
