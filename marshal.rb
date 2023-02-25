$dump = "\x04\b[\aI\"\nhello\x06:\x06ETI\"\nworld\x06;\x00T"
$index = nil
$symbols = {}

class Visitor
  attr_reader :tokens

  def initialize
    @tokens = []
  end

  def on_version(version)
    @tokens << [version, 'version']
  end

  def on_array_type(c)
    @tokens << [c, 'Array']
  end

  def on_object_with_instance_variables(c)
    @tokens << [c, 'special object with instance variables']
  end

  def on_string_type(c)
    @tokens << [c, 'String marker']
  end

  def on_true(c)
    @tokens << [c, 'true']
  end

  def on_false(c)
    @tokens << [c, 'false']
  end

  def on_symbol_type(c)
    @tokens << [c, 'Symbol marker']
  end

  def on_symbol_link(c)
    @tokens << [c, 'Symbol link']
  end

  def on_integer(string, integer)
    @tokens << [string, "Integer (#{integer})"]
  end

  def on_symbol(symbol)
    @tokens << [symbol, 'Symbol']
  end

  def on_string(string)
    @tokens << [string, 'String']
  end
end

def read(visitor)
  c = $dump[$index]
  $index += 1

  case c
  when '['
    visitor.on_array_type(c)
    read_array(visitor)
  when 'I'
    visitor.on_object_with_instance_variables(c)
    read_object_with_instance_variables(visitor)
  when '"'
    visitor.on_string_type(c)
    read_string(visitor)
  when 'T'
    visitor.on_true(c)
  when 'F'
    visitor.on_false(c)
  when ':'
    visitor.on_symbol_type(c)
    read_symbol(visitor)
  when ';'
    visitor.on_symbol_link(c)
    read_symbol_link(visitor)
  end
end

def read_array(visitor)
  count = read_integer(visitor)
  elements = (1..count).map { read(visitor) }
end

# TODO: support large Integers
def read_integer(visitor)
  i = $dump[$index].ord - 5
  visitor.on_integer($dump[$index], i)
  $index += 1
  i
end

def read_object_with_instance_variables(visitor)
  object = read(visitor)
  ivars_count = read_integer(visitor)

  ivars_count.times do
    name = read(visitor)
    value = read(visitor)
  end
end

def read_string(visitor)
  length = read_integer(visitor)
  string = $dump[$index, length]
  visitor.on_string(string)
  $index += length
end

def read_symbol(visitor)
  length = read_integer(visitor)
  symbol = $dump[$index, length]
  visitor.on_symbol(symbol)
  $index += length
  $symbols[$symbols.size] = symbol
end

def read_symbol_link(visitor)
  link = read_integer(visitor)
  $symbols[link]
end

visitor = Visitor.new

version = $dump[0, 2]
$index = 2
visitor.on_version(version)

read(visitor)

puts "Tokens with descriptions:"
visitor.tokens.each do |token, description|
  puts "#{token.dump} - #{description}"
end

puts "Tokens:"
string = visitor.tokens.map do |token, _|
  token =~ /[^[:print:]]/ ? token.dump : token
end.join(" ")
puts string
