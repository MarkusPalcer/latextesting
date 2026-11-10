# Running Tests

[← User Guide](README.md)

## Using a Host Task

Run definitions with the test command configured by the host application. The
host task is responsible for loading the gem and connecting its compiler
workflow.

## Using the Runner API Directly

For a host application that manages its own task, load the gem and use the
public runner methods:

```ruby
require "latextesting"

test_suites = LatexTesting.scan("test")
LatexTesting.run
```

`scan` recursively discovers recognized definition files and returns each
nonempty suite. Pass one of those suites to `run` to execute just that suite,
or pass one of its tests to execute a single test:

```ruby
LatexTesting.run(suite: test_suites.first)
LatexTesting.run(test: test_suites.first.tests.first)
```

Pass an options hash to enable manual visual assertions:

```ruby
LatexTesting.run(user_interaction: true)
```

With the default options, tests containing `user_assert` print the number of
skipped assertions in yellow before `MANUAL TESTS SKIPPED` (for example,
`2 MANUAL TESTS SKIPPED`) and count as passed. Interactive runs show the
assertion and PDF path and prompt for `yes`/`y` or `no`/`n`. A yes response
prints `PASSED`; a no response fails the test.

To load one particular definition file instead, use
`LatexTesting.parse_file` and then call `LatexTesting.run`.
