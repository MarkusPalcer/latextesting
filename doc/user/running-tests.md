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

fixtures = LatexTesting.scan("test")
LatexTesting.run
```

`scan` recursively discovers recognized definition files and returns fixtures.
Pass a fixture to `run` to execute all of its tests, or pass one of its tests
to run just that test (the fixture is still compiled):

```ruby
LatexTesting.run(fixture: fixtures.first)
LatexTesting.run(test: fixtures.first.tests.first)
```

Pass options to enable manual visual tests or write a JUnit XML report:

```ruby
LatexTesting.run(user_interaction: true)
LatexTesting.run(junit_report: "out/testresults.xml")
```

Manual tests are skipped by default and count as passed in the XML report.
Interactive runs show each test description and the persistent PDF path, then
prompt for `yes`/`y` or `no`/`n`. A yes response prints `PASSED`; a no
response fails that test. A fixture build failure or unexpected compilation
result fails its selected tests; a failed test does not stop later tests.

When `junit_report` is set to a filename, each run overwrites that file with a
JUnit XML report containing only the tests executed in that run. JUnit
`<testsuite>` elements represent fixtures.

To load one particular definition file instead, use `LatexTesting.parse_file`
and then call `LatexTesting.run`.
