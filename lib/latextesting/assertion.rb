# frozen_string_literal: true

module LatexTesting
  class Assertion
    def initialize(file, name, block)
      @file = file
      @name = name.to_s unless name.nil?
      @block = block
    end

    def execute(temp_dir, execution: nil)
      execution ||= Execution.new(temp_dir, @file)

      begin
        execution.instance_exec(&@block)
      rescue StandardError => e
        raise "#{@name}: #{e.message}"
      end
    end
  end
end
