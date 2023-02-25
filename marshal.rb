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
    @tokens << [VERSION, @index, 2, version]
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


dump = "\x04\b[\aI\"\nhello\x06:\x06ETI\"\nworld\x06;\x00T"
lexer = Lexer.new(dump)
lexer.run

puts "Tokens with descriptions:"
lexer.tokens.each do |token_id, index, length, *other|
  puts "#{dump[index, length].dump} - #{Lexer.token_description(token_id)} #{other.join(', ') if !other.empty?}"
end

puts ""
puts "Tokens:"
string = lexer.tokens.map do |_, index, length, *|
  token = dump[index, length]
  token =~ /[^[:print:]]/ ? token.dump : token
end.join(" ")
puts string

# dump "\nhello\x06:\x06ET
# tokens " "\n" hello "\x06" : "\x06" E T
# hierarchy:
# (" - string
#   "\n" - length
#   hello - content
#   "\x06" - ivars count
#   (: - symbol "\x06" - length E - content)
#   T - true)
