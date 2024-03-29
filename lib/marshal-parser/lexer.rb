# frozen_string_literal: true

module MarshalParser
  class Lexer
    # assign values 0, 1, 2, ...
    VERSION,
      ARRAY_PREFIX,
      OBJECT_WITH_IVARS_PREFIX,
      OBJECT_WITH_DUMP_PREFIX,
      OBJECT_WITH_MARSHAL_DUMP_PREFIX,
      STRING_PREFIX,
      HASH_PREFIX,
      HASH_WITH_DEFAULT_VALUE_PREFIX,
      REGEXP_PREFIX,
      STRUCT_PREFIX,
      TRUE,
      FALSE,
      NIL,
      FLOAT_PREFIX,
      INTEGER_PREFIX,
      BIG_INTEGER_PREFIX,
      SYMBOL_PREFIX,
      SYMBOL_LINK_PREFIX,
      CLASS_PREFIX,
      MODULE_PREFIX,
      OBJECT_PREFIX,
      OBJECT_LINK_PREFIX,
      OBJECT_EXTENDED_PREFIX,
      SUBCLASS_OF_CORE_LIBRARY_CLASS_PREFIX,
      FLOAT,
      INTEGER,
      BIG_INTEGER,
      BYTE,
      STRING,
      SYMBOL,
      PLUS_SIGN,
      MINUS_SIGN,
      UNKNOWN_SIGN = (0..100).to_a

    Token = Struct.new(:id, :index, :length, :value)

    attr_reader :tokens

    def initialize(source_string)
      @dump = source_string
      @tokens = []
    end

    def run
      @index = 0
      @tokens = []

      read_version
      read
    end

    def source_string
      @dump
    end

    private

    def read_version
      version = @dump[@index, 2]
      version_unpacked = version.unpack("CC").join(".")
      @tokens << Token.new(VERSION, @index, 2, version_unpacked)
      @index += 2
    end

    def read
      c = @dump[@index]
      @index += 1

      case c
      when "["
        @tokens << Token.new(ARRAY_PREFIX, @index - 1, 1)
        read_array
      when "I"
        @tokens << Token.new(OBJECT_WITH_IVARS_PREFIX, @index - 1, 1)
        read_object_with_instance_variables
      when '"'
        @tokens << Token.new(STRING_PREFIX, @index - 1, 1)
        read_string
      when "{"
        @tokens << Token.new(HASH_PREFIX, @index - 1, 1)
        read_hash
      when "}"
        @tokens << Token.new(HASH_WITH_DEFAULT_VALUE_PREFIX, @index - 1, 1)
        read_hash_with_default_value
      when "/"
        @tokens << Token.new(REGEXP_PREFIX, @index - 1, 1)
        read_regexp
      when "S"
        @tokens << Token.new(STRUCT_PREFIX, @index - 1, 1)
        read_struct
      when "T"
        @tokens << Token.new(TRUE, @index - 1, 1)
      when "F"
        @tokens << Token.new(FALSE, @index - 1, 1)
      when "0"
        @tokens << Token.new(NIL, @index - 1, 1)
      when ":"
        @tokens << Token.new(SYMBOL_PREFIX, @index - 1, 1)
        read_symbol
      when ";"
        @tokens << Token.new(SYMBOL_LINK_PREFIX, @index - 1, 1)
        read_symbol_link
      when "f"
        @tokens << Token.new(FLOAT_PREFIX, @index - 1, 1)
        read_float
      when "i"
        @tokens << Token.new(INTEGER_PREFIX, @index - 1, 1)
        read_integer
      when "l"
        @tokens << Token.new(BIG_INTEGER_PREFIX, @index - 1, 1)
        read_big_integer
      when "c"
        @tokens << Token.new(CLASS_PREFIX, @index - 1, 1)
        read_class
      when "m"
        @tokens << Token.new(MODULE_PREFIX, @index - 1, 1)
        read_module
      when "C"
        @tokens << Token.new(SUBCLASS_OF_CORE_LIBRARY_CLASS_PREFIX, @index - 1, 1)
        read_object_of_subclass_of_core_library_class
      when "o"
        @tokens << Token.new(OBJECT_PREFIX, @index - 1, 1)
        read_object
      when "@"
        @tokens << Token.new(OBJECT_LINK_PREFIX, @index - 1, 1)
        read_integer
      when "e"
        @tokens << Token.new(OBJECT_EXTENDED_PREFIX, @index - 1, 1)
        read_object_extended
      when "u"
        @tokens << Token.new(OBJECT_WITH_DUMP_PREFIX, @index - 1, 1)
        read_object_with_dump
      when "U"
        @tokens << Token.new(OBJECT_WITH_MARSHAL_DUMP_PREFIX, @index - 1, 1)
        read_object_with_marshal_dump
      else
        raise "Unexpected character #{c.dump} (index=#{@index - 1})"
      end
    end

    def read_array
      count = read_integer
      elements = (1..count).map { read }
    end

    def read_byte
      value = @dump[@index].ord
      @index += 1
      @tokens << Token.new(BYTE, @index - 1, 1, value)
    end

    def read_integer
      index_base = @index

      i = @dump[@index].unpack1("c")
      @index += 1

      case i
      when 0
        value = 0
      when 1
        value = @dump[@index].bytes[0]
        @index += 1
      when -1
        value = @dump[@index].bytes[0] - 255 - 1
        @index += 1
      when 2
        value = @dump[@index, 2].bytes.reverse.reduce { |acc, byte| (acc << 8) + byte }
        @index += 2
      when -2
        value = @dump[@index, 2].bytes.reverse.reduce { |acc, byte| (acc << 8) + byte } - 0xFF_FF - 1
        @index += 2
      when 3
        value = @dump[@index, 3].bytes.reverse.reduce { |acc, byte| (acc << 8) + byte }
        @index += 3
      when -3
        value = @dump[@index, 3].bytes.reverse.reduce { |acc, byte| (acc << 8) + byte } - 0xFF_FF_FF - 1
        @index += 3
      when 4
        value = @dump[@index, 4].bytes.reverse.reduce { |acc, byte| (acc << 8) + byte }
        @index += 4
      when -4
        value = @dump[@index, 4].bytes.reverse.reduce { |acc, byte| (acc << 8) + byte } - 0xFF_FF_FF_FF - 1
        @index += 4
      else
        value = i > 0 ? i - 5 : i + 5
      end

      @tokens << Token.new(INTEGER, index_base, @index - index_base, value)
      value
    end

    def read_big_integer
      sign = read_sign
      i = read_integer
      length = i * 2

      value = @dump[@index, length].bytes.reverse.reduce { |acc, byte| (acc << 8) + byte }
      value = -value if sign.id == MINUS_SIGN
      @tokens << Token.new(BIG_INTEGER, @index, length, value)

      @index += length
    end

    def read_sign
      c = @dump[@index]

      token = \
        case c
        when "+"
          Token.new(PLUS_SIGN, @index, 1)
        when "-"
          Token.new(MINUS_SIGN, @index, 1)
        else
          Token.new(UNKNOWN_SIGN, @index, 1)
        end

      @tokens << token
      @index += 1
      token
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
      @tokens << Token.new(STRING, @index, length)
      @index += length
    end

    def read_symbol
      length = read_integer
      @tokens << Token.new(SYMBOL, @index, length)
      @index += length
    end

    def read_symbol_link
      read_integer
    end

    def read_hash
      pairs_count = read_integer

      pairs_count.times do
        key = read
        value = read
      end
    end

    def read_hash_with_default_value
      pairs_count = read_integer

      pairs_count.times do
        key = read
        value = read
      end

      read # read devault value - any object
    end

    def read_regexp
      read_string # read Regexp's source
      read_byte # read flags
    end

    def read_struct
      read # read symbol (class name)
      member_count = read_integer

      member_count.times do
        read # read symbol (member name)
        read # read object (member value)
      end
    end

    def read_float
      length = read_integer
      string = @dump[@index, length]
      @tokens << Token.new(FLOAT, @index, length, Float(string))
      @index += length
    end

    def read_class
      length = read_integer
      @tokens << Token.new(STRING, @index, length)
      @index += length
    end

    def read_module
      length = read_integer
      @tokens << Token.new(STRING, @index, length)
      @index += length
    end

    def read_object_of_subclass_of_core_library_class
      read # read symbol (class name)
      read # read object
    end

    def read_object
      read # read symbol (class name)
      ivars_count = read_integer

      ivars_count.times do
        name = read
        value = read
      end
    end

    def read_object_extended
      read # read symbol (module name)
      read # read object itself
    end

    def read_object_with_dump
      read # read symbol (class name)
      read_string # read dumped string
    end

    def read_object_with_marshal_dump
      read # read symbol (class name)
      read # read object (what #marshal_dump returned)
    end
  end
end
