# frozen_string_literal: true

require "marshal-cli"
require_relative "support/fixtures"
require_relative "support/be_like_ast"
require_relative "support/has_children_nodes"
require_relative "support/has_encoded_value"
require_relative "support/has_literal_value"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
