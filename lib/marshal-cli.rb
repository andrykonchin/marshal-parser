# frozen_string_literal: true

require_relative "marshal-cli/version"
require_relative "marshal-cli/lexer"
require_relative "marshal-cli/parser"
require_relative "marshal-cli/formatters/ast/renderers/line"
require_relative "marshal-cli/formatters/ast/renderers/line_with_annotation"
require_relative "marshal-cli/formatters/ast/renderers/entries_block"
require_relative "marshal-cli/formatters/ast/renderers/renderer"
require_relative "marshal-cli/formatters/ast/renderers/renderer_with_annotations"
require_relative "marshal-cli/formatters/ast/only_tokens"
require_relative "marshal-cli/formatters/ast/sexpression"
require_relative "marshal-cli/formatters/symbols/table"
require_relative "marshal-cli/formatters/tokens/one_line"
require_relative "marshal-cli/formatters/tokens/with_description"

module MarshalCLI
  class Error < StandardError; end
  # Your code goes here...
end
