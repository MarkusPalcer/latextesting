# Assertions

[← User Guide](README.md)

## Summary

| Assertion | Explanation |
|---|---|
| `requires_log` | Checks the log for expected text |
| `assert` | Runs a custom assertion block |
| `user_assert` | Records one visual expectation |

## Log assertions

Use `requires_log` for a simple substring check:

```ruby
test "Reports a missing command" do
  file "missing-command.tex"
  expect_compilation_failure
  requires_log "Undefined control sequence"
end
```

## Custom assertions

Use `assert(name = nil) { ... }` when the check needs custom logic or a clearer
failure message:

```ruby
test "Reports the conflicting field" do
  file "field-conflict.tex"
  expect_compilation_failure

  assert "names the existing field" do
    expected = "existing field name."
    fail "Expected diagnostic was not found" unless log.include?(expected)
  end
end
```

### Assertion block helpers

The assertion block provides:

- `log` — the current fixture's LaTeX log as a string.
- `pdf_path` — the persistent path to the generated PDF in the test output
  directory.
- `generated_pdf { ... }` — access to the PDF document API.
- `fail(message)` — marks the assertion as failed with the given message.

Local variables from the surrounding test definition can be used inside an
assertion block. The test stops at the first failed assertion.

## Manual visual assertions

Use `user_assert "fact to check"` in the test definition for a visual check.
Each call should describe one fact so the result can be assessed separately:

```ruby
test "Renders a character panel" do
  file "character-panel.tex"
  user_assert 'The panel title is "Character".'
  user_assert "The panel shows the character name."
  user_assert "The weapon appears inside the panel."
end
```

By default, manual assertions are not prompted. Their skipped count is printed
in yellow before `MANUAL TESTS SKIPPED`, for example `2 MANUAL TESTS SKIPPED`.
Tests without any `user_assert` continue to print `PASS`. A `user_assert` still
fails if its generated PDF is missing, even when manual interaction is disabled.
To enable interaction, call the runner with
`LatexTesting.run(user_interaction: true)`. LatexTesting shows the assertion
text and persistent PDF path, then asks for `yes`/`y` or `no`/`n`; answers are
case-insensitive, invalid answers are re-prompted, acceptance reports
`PASSED`, and rejection fails the test.
