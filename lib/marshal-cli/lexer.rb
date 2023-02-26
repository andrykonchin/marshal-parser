module MarshalCLI
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
end
