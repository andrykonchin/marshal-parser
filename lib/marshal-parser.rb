# frozen_string_literal: true

require_relative "marshal-parser/version"
require_relative "marshal-parser/lexer"
require_relative "marshal-parser/parser"
require_relative "marshal-parser/formatters/ast/renderers/line"
require_relative "marshal-parser/formatters/ast/renderers/line_with_annotation"
require_relative "marshal-parser/formatters/ast/renderers/entries_block"
require_relative "marshal-parser/formatters/ast/renderers/renderer"
require_relative "marshal-parser/formatters/ast/renderers/renderer_with_annotations"
require_relative "marshal-parser/formatters/ast/only_tokens"
require_relative "marshal-parser/formatters/ast/sexpression"
require_relative "marshal-parser/formatters/ast/sexpression_compact"
require_relative "marshal-parser/formatters/symbols/table"
require_relative "marshal-parser/formatters/tokens/one_line"
require_relative "marshal-parser/formatters/tokens/with_description"
require_relative "marshal-parser/cli/commands"

module MarshalParser
  class Error < StandardError; end
  # Your code goes here...
end
