class Lexer
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
    @tokens << [:version, @index, 2, version]
    @index += 2
  end

  def read
    c = @dump[@index]
    @index += 1

    case c
    when '['
      @tokens << [:array_marker, @index-1, 1]
      read_array
    when 'I'
      @tokens << [:object_with_ivars_marker, @index-1, 1]
      read_object_with_instance_variables
    when '"'
      @tokens << [:string_marker, @index-1, 1]
      read_string
    when 'T'
      @tokens << [:true, @index-1, 1]
    when 'F'
      @tokens << [:false, @index-1, 1]
    when ':'
      @tokens << [:symbol_marker, @index-1, 1]
      read_symbol
    when ';'
      @tokens << [:symbol_link, @index-1, 1]
      read_symbol_link
    end
  end

  def read_array
    count = read_integer
    elements = (1..count).map { read }
  end

  # TODO: support large Integers
  def read_integer
    i = @dump[@index].ord - 5
    @tokens << [:integer, @index, 1, i]
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
    @tokens << [:string, @index, length, string]
    @index += length
  end

  def read_symbol
    length = read_integer
    symbol = @dump[@index, length]
    @tokens << [:symbol, @index, length, symbol]
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
lexer.tokens.each do |id, index, length, *other|
  puts "#{dump[index, length].dump} - #{id}, #{index}, #{length}, #{other.join(', ')}"
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
