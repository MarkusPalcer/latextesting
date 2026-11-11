# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

RuboCop::RakeTask.new

desc "Run mutation testing"
task :mutant do
  sh "bundle", "exec", "mutant", "run", "--usage", "opensource"
end

task default: %i[spec rubocop]
