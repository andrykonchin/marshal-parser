class Lexer
  VERSION           = 0
  ARRAY             = '['
  OBJECT_WITH_IVARS = 'I'
  STRING            = '"'
  TRUE_VALUE        = 'T'
  FALSE_VALUE       = 'F'
  SYMBOL            = ':'
  SYMBOL_LINK       = ';'
  INTEGER           = 1
  STRING_CONTENT    = 2
  SYMBOL_CONTENT    = 3

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
    @tokens << [VERSION, @index, 2, version_unpacked]
    @index += 2
  end

  def read
    c = @dump[@index]
    @index += 1

    case c
    when '['
      @tokens << [ARRAY, @index-1, 1]
      read_array
    when 'I'
      @tokens << [OBJECT_WITH_IVARS, @index-1, 1]
      read_object_with_instance_variables
    when '"'
      @tokens << [STRING, @index-1, 1]
      read_string
    when 'T'
      @tokens << [TRUE_VALUE, @index-1, 1]
    when 'F'
      @tokens << [FALSE_VALUE, @index-1, 1]
    when ':'
      @tokens << [SYMBOL, @index-1, 1]
      read_symbol
    when ';'
      @tokens << [SYMBOL_LINK, @index-1, 1]
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
    @tokens << [INTEGER, @index, 1, i]
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
    @tokens << [STRING_CONTENT, @index, length, string]
    @index += length
  end

  def read_symbol
    length = read_integer
    symbol = @dump[@index, length]
    @tokens << [SYMBOL_CONTENT, @index, length, symbol]
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
      @tokens.map do |_, index, length, *|
        token = @source_string[index, length]
        token =~ /[^[:print:]]/ ? token.dump : token
      end.join(" ")
    end
  end

  class WithDescription
    def initialize(tokens, source_string)
      @tokens = tokens
      @source_string = source_string
    end

    def string
      @tokens.map do |token_id, index, length, *other|
        value = @source_string[index, length].dump
        description = Lexer.token_description(token_id)
        other_list = '(' + other.join(', ') + ')' if !other.empty?

        "%-10s - %s %s" % [value, description, other_list]
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
