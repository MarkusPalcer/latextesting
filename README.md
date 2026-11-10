# LatexTesting

LatexTesting is a Ruby DSL and runner for tests that compile LaTeX fixtures,
check build logs, and inspect generated PDFs.

See the [documentation contents](doc/README.md) for separate black-box
[user guides](doc/user/README.md) and [developer guides](doc/developer/README.md).

## Using in a Host Project

Add LatexTesting to the host application's bundle using the source or path
appropriate for your environment. The host project is responsible for
providing a task that loads and runs definitions, and for connecting a LaTeX
compiler to the framework.

## Development and Specs

From this repository's root:

```sh
bundle install
bundle exec rspec
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
