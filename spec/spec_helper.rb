# frozen_string_literal: true

require "latextesting"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  config.around do |example|
    original_tmpdir = ENV["TMPDIR"]
    ENV["TMPDIR"] = "/tmp"
    example.run
  ensure
    ENV["TMPDIR"] = original_tmpdir
  end

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
