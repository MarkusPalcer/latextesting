# Tests

[← User Guide](README.md)

## Test declarations

| Declaration | Explanation |
|---|---|
| `test(name) { ... }` | Runs a custom check as one named test |
| `manual_test(description)` | Records one manual visual test |
| `requires_log(substring)` | Defines a named test that checks the log |

## Log tests

Use `requires_log` for a simple substring check. The generated test name
describes the expected log text:

```ruby
fixture "Missing command diagnostic" do
  file "missing-command.tex"
  expect_compilation_failure
  requires_log "Undefined control sequence"
end
```

## Automated tests

Use `test(name) { ... }` when a check needs custom logic or a clearer failure
message. Each call creates an individually reported test:

```ruby
fixture "Conflicting field diagnostic" do
  file "field-conflict.tex"
  expect_compilation_failure

  test "The log names the existing field" do
    expected = "existing field name."
    fail "Expected diagnostic was not found" unless log.include?(expected)
  end
end
```

### Test block helpers

The test block provides:

- `log` — the current fixture's LaTeX log as a string.
- `pdf_path` — the persistent path to the generated PDF.
- `generated_pdf { ... }` — access to the PDF document API.
- `fail(message)` — marks this test as failed with the given message.

Local variables from the surrounding fixture definition can be used inside a
test block. Each test runs independently; failures do not stop later tests for
the fixture.

## Manual visual tests

Use `manual_test "fact to check"` in a fixture for a visual check. Each call
defines a separately reported test and should describe one fact:

```ruby
fixture "Character panel" do
  file "character-panel.tex"
  manual_test 'The panel title is "Character".'
  manual_test "The panel shows the character name."
  manual_test "The weapon appears inside the panel."
end
```

By default, manual tests are not prompted and report `MANUAL TEST SKIPPED`.
They count as passing in JUnit but fail if the generated PDF is missing. To
enable interaction, call the runner with
`LatexTesting.run(user_interaction: true)`. LatexTesting shows the test
description and persistent PDF path, then asks for `yes`/`y` or `no`/`n`;
answers are case-insensitive, invalid answers are re-prompted, acceptance
reports `PASSED`, and rejection fails that test.
