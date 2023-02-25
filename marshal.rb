class Lexer
  VERSION           = 0
  ARRAY             = 1
  OBJECT_WITH_IVARS = 2
  STRING            = 3
  TRUE_VALUE        = 4
  FALSE_VALUE       = 5
  SYMBOL            = 6
  SYMBOL_LINK       = 7
  INTEGER           = 8
  STRING_CONTENT    = 9
  SYMBOL_CONTENT    = 10

  Token = Struct.new(:id, :index, :length, :value)

  def self.token_description(token)
    case token
      when VERSION            then "Version"
      when ARRAY              then "Array"
      when OBJECT_WITH_IVARS  then "Special object with instance variables"
      when STRING             then "String"
      when TRUE_VALUE         then "true"
      when FALSE_VALUE        then "false"
      when SYMBOL             then "Symbol"
      when SYMBOL_LINK        then "Link to Symbol"
      when INTEGER            then "Integer"
      when STRING_CONTENT     then "String characters"
      when SYMBOL_CONTENT     then "Symbol characters"
    end
  end

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
      @tokens << Token.new(ARRAY, @index-1, 1)
      read_array
    when 'I'
      @tokens << Token.new(OBJECT_WITH_IVARS, @index-1, 1)
      read_object_with_instance_variables
    when '"'
      @tokens << Token.new(STRING, @index-1, 1)
      read_string
    when 'T'
      @tokens << Token.new(TRUE_VALUE, @index-1, 1)
    when 'F'
      @tokens << Token.new(FALSE_VALUE, @index-1, 1)
    when ':'
      @tokens << Token.new(SYMBOL, @index-1, 1)
      read_symbol
    when ';'
      @tokens << Token.new(SYMBOL_LINK, @index-1, 1)
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
    @tokens << Token.new(STRING_CONTENT, @index, length, string)
    @index += length
  end

  def read_symbol
    length = read_integer
    symbol = @dump[@index, length]
    @tokens << Token.new(SYMBOL_CONTENT, @index, length, symbol)
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
        description = Lexer.token_description(token.id)
        value = token.value ? "(#{token.value})" : ""

        "%-10s - %s %s" % [string, description, value]
      end.join("\n")
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
  def initialize(lexer)
    @lexer = lexer
    @index = 0
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

    when Lexer::ARRAY
      length = next_token
      elements = []

      length.value.times do
        elements << build_ast_node
      end

      ArrayNode.new(token, length, elements)

    when Lexer::STRING
      length = next_token
      content = next_token

      StringNode.new(token, length, content)

    when Lexer::OBJECT_WITH_IVARS
      child = build_ast_node

      count = next_token
      ivars = []

      count.value.times do
        name = build_ast_node
        value = build_ast_node
        ivars << [name, value]

        ensure_node_type(name, [SymbolNode, SymbolLinkNode])
      end

      ObjectWithIVarsNode.new(token, count, ivars)

    when Lexer::SYMBOL
      length = next_token
      content = next_token

      SymbolNode.new(token, length, content)

    when Lexer::TRUE_VALUE
      TrueNode.new(token)

    when Lexer::FALSE_VALUE
      FalseNode.new(token)

    when Lexer::SYMBOL_LINK
      index = next_token

      SymbolLinkNode.new(token, index)
    end
  end

  def next_token
    raise "No next token" if @index >= @lexer.tokens.size

    @index += 1
    @lexer.tokens[@index-1]
  end

  def ensure_node_type(node, allowed_classes)
    return if allowed_classes.any? { |node_class| node_class === node }
    raise "Node #{node} should be a #{allowed_classes.map(&:name).join(' or ')}"
  end

  class Node
    def ensure_token_type(token, expected_token_id)
      return if token.id == expected_token_id
      raise "Token #{token} should have type #{expected_token_id}"
    end
  end

  class VersionNode < Node
    def initialize(version_token)
      ensure_token_type(version_token, Lexer::VERSION)
      @version_token = version_token
    end
  end

  class ArrayNode < Node
    def initialize(marker_token, length_token, elements_nodes)
      ensure_token_type(marker_token, Lexer::ARRAY)
      ensure_token_type(length_token, Lexer::INTEGER)

      @marker_token = marker_token
      @length_token = length_token
      @elements_nodes = elements_nodes
    end
  end

  class StringNode < Node
    def initialize(marker_token, length_token, content_token)
      ensure_token_type(marker_token, Lexer::STRING)
      ensure_token_type(length_token, Lexer::INTEGER)
      ensure_token_type(content_token, Lexer::STRING_CONTENT)

      @marker_token = marker_token
      @length_token = length_token
      @content_token = content_token
    end
  end

  class ObjectWithIVarsNode < Node
    def initialize(marker_token, count_token, ivars_nodes)
      ensure_token_type(marker_token, Lexer::OBJECT_WITH_IVARS)
      ensure_token_type(count_token, Lexer::INTEGER)

      @marker_token = marker_token
      @count_token = count_token
      @ivars_nodes = ivars_nodes
    end
  end

  class SymbolNode < Node
    def initialize(marker_token, length_token, content_token)
      ensure_token_type(marker_token, Lexer::SYMBOL)
      ensure_token_type(length_token, Lexer::INTEGER)
      ensure_token_type(content_token, Lexer::SYMBOL_CONTENT)

      @marker_token = marker_token
      @length_token = length_token
      @content_token = content_token
    end
  end

  class TrueNode < Node
    def initialize(token)
      ensure_token_type(token, Lexer::TRUE_VALUE)
      @token = token
    end
  end

  class FalseNode < Node
    def initialize(token)
      ensure_token_type(token, Lexer::FalseNode)
      @token = token
    end
  end

  class SymbolLinkNode < Node
    def initialize(marker_token, index_token)
      ensure_token_type(marker_token, Lexer::SYMBOL_LINK)
      ensure_token_type(index_token, Lexer::INTEGER)

      @marker_token = marker_token
      @index_token = index_token
    end
  end
end

dump = "\x04\b[\aI\"\nhello\x06:\x06ETI\"\nworld\x06;\x00T"
lexer = Lexer.new(dump)
lexer.run

require 'pp'
puts ""
puts "AST:"
parser = Parser.new(lexer)
pp parser.parse

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
