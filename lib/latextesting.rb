# frozen_string_literal: true

require_relative "latextesting/version"

require "fileutils"
require "pathname"
require "tmpdir"

require_relative "latextesting/error"
require_relative "latextesting/assertion"
require_relative "latextesting/assertion/execution"
require_relative "latextesting/target_unit"
require_relative "latextesting/assertion/pdf_frame"
require_relative "latextesting/assertion/pdf_frame_collection"
require_relative "latextesting/assertion/pdf_page"
require_relative "latextesting/assertion/pdf_page_collection"
require_relative "latextesting/assertion/pdf_execution"
require_relative "latextesting/test"
require_relative "latextesting/test_suite"
require_relative "latextesting/test_file"
require_relative "latextesting/junit_report"
require_relative "latextesting/runner"

module LatexTesting
  GREEN = "\e[32m"
  YELLOW = "\e[33m"
  RED = "\e[31m"
  RESET = "\e[0m"

  PROJECT_ROOT = Pathname(Dir.pwd).realpath.freeze
  OUT_DIR = PROJECT_ROOT.join("out").freeze
end
