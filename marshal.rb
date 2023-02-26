module Assertable
  def assert(boolean, message)
    raise "Assert failed: #{message}" unless boolean
  end
end

class Lexer
  # assign values 0, 1, 2, ...
  VERSION,
  ARRAY_PREFIX,
  OBJECT_WITH_IVARS_PREFIX,
  STRING_PREFIX,
  TRUE,
  FALSE,
  SYMBOL_PREFIX,
  SYMBOL_LINK_PREFIX,
  INTEGER,
  STRING,
  SYMBOL = (0..100).to_a

  Token = Struct.new(:id, :index, :length, :value)

  attr_reader :tokens

  def initialize(string)
    @dump = string
    @tokens = []
  end

  def run
    @index = 0
    @tokens = []

    read_version
    read
  end

  private

  def read_version
    version = @dump[@index, 2]
    version_unpacked = version.unpack("CC").join('.')
    @tokens << Token.new(VERSION, @index, 2, version_unpacked)
    @index += 2
  end

  def read
    c = @dump[@index]
    @index += 1

    case c
    when '['
      @tokens << Token.new(ARRAY_PREFIX, @index-1, 1)
      read_array
    when 'I'
      @tokens << Token.new(OBJECT_WITH_IVARS_PREFIX, @index-1, 1)
      read_object_with_instance_variables
    when '"'
      @tokens << Token.new(STRING_PREFIX, @index-1, 1)
      read_string
    when 'T'
      @tokens << Token.new(TRUE, @index-1, 1, true)
    when 'F'
      @tokens << Token.new(FALSE, @index-1, 1, false)
    when ':'
      @tokens << Token.new(SYMBOL_PREFIX, @index-1, 1)
      read_symbol
    when ';'
      @tokens << Token.new(SYMBOL_LINK_PREFIX, @index-1, 1)
      read_symbol_link
    end
  end

  def read_array
    count = read_integer
    elements = (1..count).map { read }
  end

  # TODO: support large Integers
  def read_integer
    i = @dump[@index].ord
    i -= 5 if i != 0
    @tokens << Token.new(INTEGER, @index, 1, i)
    @index += 1
    i
  end

  def read_object_with_instance_variables
    object = read
    ivars_count = read_integer

    ivars_count.times do
      name = read
      value = read
    end
  end

  def read_string
    length = read_integer
    string = @dump[@index, length]
    @tokens << Token.new(STRING, @index, length, string)
    @index += length
  end

  def read_symbol
    length = read_integer
    symbol = @dump[@index, length]
    @tokens << Token.new(SYMBOL, @index, length, symbol)
    @index += length
  end

  def read_symbol_link
    read_integer
  end
end

module TokensFormatter
  class OneLine
    def initialize(tokens, source_string)
      @tokens = tokens
      @source_string = source_string
    end

    def string
      @tokens.map do |token|
        string = @source_string[token.index, token.length]
        string =~ /[^[:print:]]/ ? string.dump : string
      end.join(" ")
    end
  end

  class WithDescription
    def initialize(tokens, source_string)
      @tokens = tokens
      @source_string = source_string
    end

    def string
      @tokens.map do |token|
        string = @source_string[token.index, token.length].dump
        description = self.class.token_description(token.id)
        value = token.value ? "(#{token.value})" : ""

        "%-10s - %s %s" % [string, description, value]
      end.join("\n")
    end

    def self.token_description(token)
      case token
      when Lexer::VERSION                   then "Version"
      when Lexer::ARRAY_PREFIX              then "Array"
      when Lexer::OBJECT_WITH_IVARS_PREFIX  then "Special object with instance variables"
      when Lexer::STRING_PREFIX             then "String"
      when Lexer::TRUE                      then "true"
      when Lexer::FALSE                     then "false"
      when Lexer::SYMBOL_PREFIX             then "Symbol"
      when Lexer::SYMBOL_LINK_PREFIX        then "Link to Symbol"
      when Lexer::INTEGER                   then "Integer"
      when Lexer::STRING                    then "String characters"
      when Lexer::SYMBOL                    then "Symbol characters"
      end
    end
  end
end

dump = "\x04\b[\aI\"\nhello\x06:\x06ETI\"\nworld\x06;\x00T"
lexer = Lexer.new(dump)
lexer.run

puts "Tokens:"
formatter = TokensFormatter::OneLine.new(lexer.tokens, dump)
puts formatter.string

puts ""

puts "Tokens with descriptions:"
formatter = TokensFormatter::WithDescription.new(lexer.tokens, dump)
puts formatter.string

class Parser
  include Assertable

  attr_reader :symbols

  def initialize(lexer)
    @lexer = lexer
    @index = 0
    @symbols = []
  end

  def parse
    version_node = build_ast_node
    root_node = build_ast_node
    root_node
  end

  private

  def build_ast_node
    token = next_token

    case token.id
    when Lexer::VERSION
      VersionNode.new(token)

    when Lexer::ARRAY_PREFIX
      length = next_token
      elements = []

      length.value.times do
        elements << build_ast_node
      end

      ArrayNode.new(token, length, elements)

    when Lexer::STRING_PREFIX
      length = next_token
      content = next_token

      StringNode.new(token, length, content)

    when Lexer::OBJECT_WITH_IVARS_PREFIX
      child = build_ast_node

      count = next_token
      ivars = []

      count.value.times do
        name = build_ast_node
        value = build_ast_node
        ivars << name << value

        assert_node_type(name, [SymbolNode, SymbolLinkNode])
      end

      ObjectWithIVarsNode.new(token, count, ivars)

    when Lexer::SYMBOL_PREFIX
      length = next_token
      content = next_token
      @symbols << content.value

      SymbolNode.new(token, length, content, @symbols.size-1)

    when Lexer::TRUE
      TrueNode.new(token)

    when Lexer::FALSE
      FalseNode.new(token)

    when Lexer::SYMBOL_LINK_PREFIX
      index = next_token

      SymbolLinkNode.new(token, index)
    end
  end

  def next_token
    raise "No next token" if @index >= @lexer.tokens.size

    @index += 1
    @lexer.tokens[@index-1]
  end

  def assert_node_type(node, allowed_classes)
    assert(
      allowed_classes.any? { |node_class| node_class === node },
      "Node #{node} should be a #{allowed_classes.map(&:name).join(' or ')}")
  end

  class Node
    include Assertable

    def tokens
      []
    end

    def children
      []
    end

    private

    def assert_token_type(token, expected_token_id)
      assert(
        token.id == expected_token_id,
        "Token #{token} should have type #{expected_token_id}")
    end
  end

  class VersionNode < Node
    def initialize(version_token)
      assert_token_type version_token, Lexer::VERSION
      @version_token = version_token
    end

    def tokens
      [@version_token]
    end
  end

  module Annotatable
    def annotation
      raise "Not implemented"
    end
  end

  class ArrayNode < Node
    def initialize(marker_token, length_token, elements_nodes)
      assert_token_type marker_token, Lexer::ARRAY_PREFIX
      assert_token_type length_token, Lexer::INTEGER

      @marker_token = marker_token
      @length_token = length_token
      @elements_nodes = elements_nodes
    end

    def tokens
      [@marker_token, @length_token]
    end

    def children
      @elements_nodes
    end
  end

  class StringNode < Node
    def initialize(marker_token, length_token, content_token)
      assert_token_type marker_token, Lexer::STRING_PREFIX
      assert_token_type length_token, Lexer::INTEGER
      assert_token_type content_token, Lexer::STRING

      @marker_token = marker_token
      @length_token = length_token
      @content_token = content_token
    end

    def tokens
      [@marker_token, @length_token, @content_token]
    end
  end

  class ObjectWithIVarsNode < Node
    def initialize(marker_token, count_token, ivars_nodes)
      assert_token_type marker_token, Lexer::OBJECT_WITH_IVARS_PREFIX
      assert_token_type count_token, Lexer::INTEGER

      @marker_token = marker_token
      @count_token = count_token
      @ivars_nodes = ivars_nodes
    end

    def tokens
      [@marker_token, @count_token]
    end

    def children
      @ivars_nodes
    end
  end

  class SymbolNode < Node
    include Annotatable

    def initialize(marker_token, length_token, content_token, symbol_number)
      assert_token_type marker_token, Lexer::SYMBOL_PREFIX
      assert_token_type length_token, Lexer::INTEGER
      assert_token_type content_token, Lexer::SYMBOL

      @marker_token = marker_token
      @length_token = length_token
      @content_token = content_token
      @symbol_number = symbol_number
    end

    def tokens
      [@marker_token, @length_token, @content_token]
    end

    def annotation
      "symbol ##{@symbol_number}"
    end
  end

  class TrueNode < Node
    def initialize(token)
      assert_token_type(token, Lexer::TRUE)
      @token = token
    end

    def tokens
      [@token]
    end
  end

  class FalseNode < Node
    def initialize(token)
      assert_token_type token, Lexer::FalseNode
      @token = token
    end

    def tokens
      [@token]
    end
  end

  class SymbolLinkNode < Node
    include Annotatable

    def initialize(marker_token, index_token)
      assert_token_type marker_token, Lexer::SYMBOL_LINK_PREFIX
      assert_token_type index_token, Lexer::INTEGER

      @marker_token = marker_token
      @index_token = index_token
    end

    def tokens
      [@marker_token, @index_token]
    end

    def annotation
      "link to symbol ##{@index_token.value}"
    end
  end

  module ASTFormatter
    class SExpression
      def initialize(node, source_string)
        @node = node
        @source_string = source_string
      end

      def string
        tokens = @node.tokens.map do |t|
          string = @source_string[t.index, t.length]
          string =~ /[^[:print:]]/ ? string.dump : string
        end
        children = @node.children.map { |child| SExpression.new(child, @source_string).string }
        annotation = @node.annotation if @node.is_a? Annotatable

        # print just T and F instead of (T) and (F)
        if tokens.size == 1 && children.empty?
          if annotation
            return tokens[0] + " " * 10 + annotation
          else
            return tokens[0]
          end
        end

        head_token = tokens[0]
        rest_tokens = tokens[1..-1]
        indent = " "*2

        sexpression = "(#{head_token}"
        unless rest_tokens.empty?
          if children.empty?
            # short oneline form, e.g. (: "\x06" E)
            sexpression += " " + rest_tokens.join(" ")
          else
            # multiline form
            sexpression += "\n" + rest_tokens.map { |t| "#{indent}#{t}" }.join("\n")
          end
        end
        unless children.empty?
          sexpression += "\n" + children.map { |c| indent + c.gsub(/\n/, "\n#{indent}") }.join("\n")
        end
        sexpression << ")"

        if annotation
          if sexpression.lines.size > 1
            sexpression.sub!(/\n/, " " * 10 + "#" + annotation + "\n")
          else
            sexpression += " " * 10 + "#" + annotation
          end
        end

        sexpression
      end
    end

    class SymbolsTable
      def initialize(symbols)
        @symbols = symbols
      end

      def string
        @symbols.map.with_index do |symbol, i|
          "%-4d - :%s" % [i, symbol]
        end.join("\n")
      end
    end
  end
end

dump = "\x04\b[\aI\"\nhello\x06:\x06ETI\"\nworld\x06;\x00T"
lexer = Lexer.new(dump)
lexer.run

parser = Parser.new(lexer)
ast = parser.parse

#require 'pp'
#puts ""
#puts "AST:"
#pp ast

puts ""
puts "S-expression:"
puts Parser::ASTFormatter::SExpression.new(ast, dump).string

symbols = parser.symbols
puts ""
puts "Symbols table"
puts Parser::ASTFormatter::SymbolsTable.new(symbols).string

# dump "\nhello\x06:\x06ET
# tokens " "\n" hello "\x06" : "\x06" E T
# hierarchy:
# ("
#   "\n" [length=5]
#   hello
#   "\x06" [ivars count=1]
#   (:
#      "\x06" [length=1]
#       E)
#   T [true])
