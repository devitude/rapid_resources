require "rapid_resources/engine"

module RapidResources
  # Your code goes here...
  class Base
    cattr_accessor :report_exception_proc, default: Proc.new { |ex| Rails.logger.error("Exception: #{ex.message}\n#{ex.backtrace.join("\n")}") }
  end
end
