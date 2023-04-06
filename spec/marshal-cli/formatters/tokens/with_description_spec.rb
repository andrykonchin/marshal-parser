# frozen_string_literal: true
require 'bigdecimal'

RSpec.describe MarshalParser::Formatters::Tokens::WithDescription do
  describe '#string' do
    def formatted_output(string)
      lexer = MarshalParser::Lexer.new(string)
      lexer.run
      tokens = lexer.tokens

      formatter = described_class.new(tokens, string)
      formatter.string
    end

    it 'returns tokens for dumped true' do
      dump = "\x04\bT"
      expect(Marshal.dump(true)).to eq dump

      expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
        "\x04\b"   - Version (4.8)
        "T"        - true
      STR
    end

    it 'returns tokens for dumped false' do
      dump = "\x04\bF"
      expect(Marshal.dump(false)).to eq dump

      expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
        "\x04\b"   - Version (4.8)
        "F"        - false
      STR
    end

    it 'returns tokens for dumped nil' do
      dump = "\x04\b0"
      expect(Marshal.dump(nil)).to eq dump

      expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
        "\x04\b"   - Version (4.8)
        "0"        - nil
      STR
    end

    describe 'Integer' do
      it 'returns tokens for dumped 0' do
        dump = "\x04\bi\x00".b
        expect(Marshal.dump(0)).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          "\x04\b"   - Version (4.8)
          "i"        - Integer beginning
          "\x00"     - Integer encoded (0)
        STR
      end

      it 'returns tokens for dumped 5..122 (a sign-extended eight-bit value with an offset)' do
        dump = "\x04\bi\x7F".b
        expect(Marshal.dump(122)).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          "\x04\b"   - Version (4.8)
          "i"        - Integer beginning
          "\x7F"     - Integer encoded (122)
        STR
      end

      it 'returns tokens for dumped -122..-5 (a sign-extended eight-bit value with an offset)' do
        dump = "\x04\bi\x81".b
        expect(Marshal.dump(-122)).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          "\x04\b"   - Version (4.8)
          "i"        - Integer beginning
          "\x81"     - Integer encoded (-122)
        STR
      end

      it 'returns tokens for dumped 123..255 (0x01 + the following byte is a positive integer)' do
        dump = "\x04\bi\x01\xFF".b
        expect(Marshal.dump(255)).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          "\x04\b"   - Version (4.8)
          "i"        - Integer beginning
          "\x01\xFF" - Integer encoded (255)
        STR
      end

      it 'returns tokens for dumped -256..-124 (0xFF + the following byte is a negative integer)' do
        dump = "\x04\bi\xFF\x01".b
        expect(Marshal.dump(-255)).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          "\x04\b"   - Version (4.8)
          "i"        - Integer beginning
          "\xFF\x01" - Integer encoded (-255)
        STR
      end

      it 'returns tokens for dumped XX XX (0x02 + the following 2 bytes is a positive little-endian integer)' do
        dump = "\x04\bi\x024\x12".b
        expect(Marshal.dump(0x1234)).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          "\x04\b"   - Version (4.8)
          "i"        - Integer beginning
          "\x024\x12" - Integer encoded (4660)
        STR
      end

      it 'returns tokens for dumped -XX XX (0xFE + the following 2 bytes is a negative little-endian integer)' do
        dump = "\x04\bi\xFE\xCC\xED".b
        expect(Marshal.dump(-0x1234)).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          "\x04\b"   - Version (4.8)
          "i"        - Integer beginning
          "\xFE\xCC\xED" - Integer encoded (-4660)
        STR
      end

      it 'returns tokens for dumped XX XX XX (0x03 + the following 3 bytes is a positive little-endian integer)' do
        dump = "\x04\bi\x03V4\x12".b
        expect(Marshal.dump(0x123456)).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          "\x04\b"   - Version (4.8)
          "i"        - Integer beginning
          "\x03V4\x12" - Integer encoded (1193046)
        STR
      end

      it 'returns tokens for dumped -XX XX XX (0xFD + the following 3 bytes is a negative little-endian integer)' do
        dump = "\x04\bi\xFD\xAA\xCB\xED".b
        expect(Marshal.dump(-0x123456)).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          "\x04\b"   - Version (4.8)
          "i"        - Integer beginning
          "\xFD\xAA\xCB\xED" - Integer encoded (-1193046)
        STR
      end

      it 'returns tokens for dumped XX XX XX XX (0x04 + the following 4 bytes is a positive little-endian integer)' do
        dump = "\x04\bi\x04xV4\x12".b
        expect(Marshal.dump(0x12345678)).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          "\x04\b"   - Version (4.8)
          "i"        - Integer beginning
          "\x04xV4\x12" - Integer encoded (305419896)
        STR
      end

      it 'returns tokens for dumped -XX XX XX XX (0xFC + the following 4 bytes is a negative little-endian integer)' do
        dump = "\x04\bi\xFC\x88\xA9\xCB\xED".b
        expect(Marshal.dump(-0x12345678)).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          "\x04\b"   - Version (4.8)
          "i"        - Integer beginning
          "\xFC\x88\xA9\xCB\xED" - Integer encoded (-305419896)
        STR
      end

      it 'returns tokens for dumped positive big Integer (Bignum, > 2^32)' do
        dump = "\x04\bl+\b\x01\x00\x00\x00\x01\x00".b
        expect(Marshal.dump(2.pow(32) + 1)).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          "\x04\b"   - Version (4.8)
          "l"        - Big Integer beginning
          "+"        - Sign '+'
          "\b"       - Integer encoded (3)
          "\x01\x00\x00\x00\x01\x00" - Big Integer encoded (4294967297)
        STR
      end

      it 'returns tokens for dumped negative big Integer (Bignum)' do
        dump = "\x04\bl-\b\x01\x00\x00\x00\x01\x00".b
        expect(Marshal.dump(-(2.pow(32)) - 1)).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          "\x04\b"   - Version (4.8)
          "l"        - Big Integer beginning
          "-"        - Sign '-'
          "\b"       - Integer encoded (3)
          "\x01\x00\x00\x00\x01\x00" - Big Integer encoded (-4294967297)
        STR
      end
    end

    it 'returns tokens for dumped Float' do
      dump = "\x04\bf\t3.14"
      expect(Marshal.dump(3.14)).to eq dump

      expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
        "\x04\b"   - Version (4.8)
        "f"        - Float beginning
        "\t"       - Integer encoded (4)
        "3.14"     - Float string representation (3.14)
      STR
    end

    it 'returns tokens for dumped Rational' do
      dump = "\x04\bU:\rRational[\ai\x06i\a"
      expect(Marshal.dump(Rational(1, 2))).to eq dump

      expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
        "\x04\b"   - Version (4.8)
        "U"        - Object with #marshal_dump and #marshal_load
        ":"        - Symbol beginning
        "\r"       - Integer encoded (8)
        "Rational" - Symbol characters
        "["        - Array beginning
        "\a"       - Integer encoded (2)
        "i"        - Integer beginning
        "\x06"     - Integer encoded (1)
        "i"        - Integer beginning
        "\a"       - Integer encoded (2)
      STR
    end

    it 'returns tokens for dumped Complex' do
      dump = "\x04\bU:\fComplex[\ai\x06i\a"
      expect(Marshal.dump(Complex(1, 2))).to eq dump

      expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
        "\x04\b"   - Version (4.8)
        "U"        - Object with #marshal_dump and #marshal_load
        ":"        - Symbol beginning
        "\f"       - Integer encoded (7)
        "Complex"  - Symbol characters
        "["        - Array beginning
        "\a"       - Integer encoded (2)
        "i"        - Integer beginning
        "\x06"     - Integer encoded (1)
        "i"        - Integer beginning
        "\a"       - Integer encoded (2)
      STR
    end

    it 'returns tokens for dumped String' do
      dump = "\x04\bI\"\nHello\x06:\x06ET"
      expect(Marshal.dump('Hello')).to eq dump

      expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
        "\x04\b"   - Version (4.8)
        "I"        - Special object with instance variables
        "\""       - String beginning
        "\n"       - Integer encoded (5)
        "Hello"    - String characters
        "\x06"     - Integer encoded (1)
        ":"        - Symbol beginning
        "\x06"     - Integer encoded (1)
        "E"        - Symbol characters
        "T"        - true
      STR
    end

    it 'returns tokens for dumped Symbol' do
      dump = "\x04\b:\nHello"
      expect(Marshal.dump(:Hello)).to eq dump

      expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
        "\x04\b"   - Version (4.8)
        ":"        - Symbol beginning
        "\n"       - Integer encoded (5)
        "Hello"    - Symbol characters
      STR
    end

    it 'returns tokens for dumped Symbol when there are duplicates' do
      dump = "\x04\b[\b:\nHello:\nworld;\x00"
      expect(Marshal.dump([:Hello, :world, :Hello])).to eq dump

      expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
        "\x04\b"   - Version (4.8)
        "["        - Array beginning
        "\b"       - Integer encoded (3)
        ":"        - Symbol beginning
        "\n"       - Integer encoded (5)
        "Hello"    - Symbol characters
        ":"        - Symbol beginning
        "\n"       - Integer encoded (5)
        "world"    - Symbol characters
        ";"        - Link to Symbol
        "\x00"     - Integer encoded (0)
      STR
    end

    it 'returns tokens for dumped Array' do
      dump = "\x04\b[\aTF"
      expect(Marshal.dump([true, false])).to eq dump

      expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
        "\x04\b"   - Version (4.8)
        "["        - Array beginning
        "\a"       - Integer encoded (2)
        "T"        - true
        "F"        - false
      STR
    end

    describe 'Hash' do
      it 'returns tokens for dumped Hash' do
        dump = "\x04\b{\x06:\x06ai\x00"
        expect(Marshal.dump({a: 0})).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          "\x04\b"   - Version (4.8)
          "{"        - Hash beginning
          "\x06"     - Integer encoded (1)
          ":"        - Symbol beginning
          "\x06"     - Integer encoded (1)
          "a"        - Symbol characters
          "i"        - Integer beginning
          "\x00"     - Integer encoded (0)
        STR
      end

      it 'returns tokens for dumped Hash with default value' do
        dump = "\x04\b}\x00i/"

        hash = Hash.new(42)
        expect(Marshal.dump(hash)).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          "\x04\b"   - Version (4.8)
          "}"        - Hash beginning (with defaul value)
          "\x00"     - Integer encoded (0)
          "i"        - Integer beginning
          "/"        - Integer encoded (42)
        STR
      end

      it 'returns tokens for dumped Hash with compare-by-identity behabiour' do
        dump = "\x04\bC:\tHash{\x00"

        hash = {}
        hash.compare_by_identity
        expect(Marshal.dump(hash)).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          "\x04\b"   - Version (4.8)
          "C"        - Instance of a Core Library class subclass beginning
          ":"        - Symbol beginning
          "\t"       - Integer encoded (4)
          "Hash"     - Symbol characters
          "{"        - Hash beginning
          "\x00"     - Integer encoded (0)
        STR
      end
    end

    it 'returns tokens for dumped Range' do
      dump = "\x04\bo:\nRange\b:\texclF:\nbegini\x00:\bendi/"
      expect(Marshal.dump(0..42)).to eq dump

      expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
        "\x04\b"   - Version (4.8)
        "o"        - Object beginning
        ":"        - Symbol beginning
        "\n"       - Integer encoded (5)
        "Range"    - Symbol characters
        "\b"       - Integer encoded (3)
        ":"        - Symbol beginning
        "\t"       - Integer encoded (4)
        "excl"     - Symbol characters
        "F"        - false
        ":"        - Symbol beginning
        "\n"       - Integer encoded (5)
        "begin"    - Symbol characters
        "i"        - Integer beginning
        "\x00"     - Integer encoded (0)
        ":"        - Symbol beginning
        "\b"       - Integer encoded (3)
        "end"      - Symbol characters
        "i"        - Integer beginning
        "/"        - Integer encoded (42)
      STR
    end

    it 'returns tokens for dumped Regexp' do
      dump = "\x04\bI/\babc\x00\x06:\x06EF"
      expect(Marshal.dump(/abc/)).to eq dump

      expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
        "\x04\b"   - Version (4.8)
        "I"        - Special object with instance variables
        "/"        - Regexp beginning
        "\b"       - Integer encoded (3)
        "abc"      - String characters
        "\x00"     - Integer encoded (0)
        "\x06"     - Integer encoded (1)
        ":"        - Symbol beginning
        "\x06"     - Integer encoded (1)
        "E"        - Symbol characters
        "F"        - false
      STR
    end

    describe 'Time' do
      it 'returns tokens for dumped Time' do
        dump = "\x04\bIu:\tTime\ri\xC7\x1E\x80\x00\x00\xE0\xCD\a:\voffseti\x020*:\tzone0".b

        time = Time.new(2023, 2, 27, 12, 51, 30, "+0300")
        expect(Marshal.dump(time)).to eq dump.b

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          "\x04\b"   - Version (4.8)
          "I"        - Special object with instance variables
          "u"        - Object with #_dump and .load
          ":"        - Symbol beginning
          "\t"       - Integer encoded (4)
          "Time"     - Symbol characters
          "\r"       - Integer encoded (8)
          "i\xC7\x1E\x80\x00\x00\xE0\xCD" - String characters
          "\a"       - Integer encoded (2)
          ":"        - Symbol beginning
          "\v"       - Integer encoded (6)
          "offset"   - Symbol characters
          "i"        - Integer beginning
          "\x020*"   - Integer encoded (10800)
          ":"        - Symbol beginning
          "\t"       - Integer encoded (4)
          "zone"     - Symbol characters
          "0"        - nil
        STR
      end

      it 'returns tokens for dumped Time in UTC' do
        dump = "\x04\bIu:\tTime\rl\xC7\x1E\xC0,\x01\xE0\xCD\x06:\tzoneI\"\bUTC\x06:\x06EF".b

        time = Time.utc(2023, 2, 27, 12, 51, 30, "+0300")
        expect(Marshal.dump(time)).to eq dump.b

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          "\x04\b"   - Version (4.8)
          "I"        - Special object with instance variables
          "u"        - Object with #_dump and .load
          ":"        - Symbol beginning
          "\t"       - Integer encoded (4)
          "Time"     - Symbol characters
          "\r"       - Integer encoded (8)
          "l\xC7\x1E\xC0,\x01\xE0\xCD" - String characters
          "\x06"     - Integer encoded (1)
          ":"        - Symbol beginning
          "\t"       - Integer encoded (4)
          "zone"     - Symbol characters
          "I"        - Special object with instance variables
          "\""       - String beginning
          "\b"       - Integer encoded (3)
          "UTC"      - String characters
          "\x06"     - Integer encoded (1)
          ":"        - Symbol beginning
          "\x06"     - Integer encoded (1)
          "E"        - Symbol characters
          "F"        - false
        STR
      end
    end

    it 'returns tokens for dumped Class' do
      dump = "\x04\bc\vString"
      expect(Marshal.dump(String)).to eq dump

      expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
        "\x04\b"   - Version (4.8)
        "c"        - Class beginning
        "\v"       - Integer encoded (6)
        "String"   - String characters
      STR
    end

    it 'returns tokens for dumped Module' do
      dump = "\x04\bm\x0FEnumerable"
      expect(Marshal.dump(Enumerable)).to eq dump

      expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
        "\x04\b"   - Version (4.8)
        "m"        - Module beginning
        "\x0F"     - Integer encoded (10)
        "Enumerable" - String characters
      STR
    end

    it 'returns tokens for dumped Struct' do
      dump = "\x04\bS:\fStructA\x06:\x06ai\x06"
      expect(Marshal.dump(StructA.new(1))).to eq dump

      expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
        "\x04\b"   - Version (4.8)
        "S"        - Struct beginning
        ":"        - Symbol beginning
        "\f"       - Integer encoded (7)
        "StructA"  - Symbol characters
        "\x06"     - Integer encoded (1)
        ":"        - Symbol beginning
        "\x06"     - Integer encoded (1)
        "a"        - Symbol characters
        "i"        - Integer beginning
        "\x06"     - Integer encoded (1)
      STR
    end

    it 'returns tokens for dumped Encoding' do
      dump = "\x04\bIu:\rEncoding\nUTF-8\x06:\x06EF"
      expect(Marshal.dump(Encoding::UTF_8)).to eq dump

      expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
        "\x04\b"   - Version (4.8)
        "I"        - Special object with instance variables
        "u"        - Object with #_dump and .load
        ":"        - Symbol beginning
        "\r"       - Integer encoded (8)
        "Encoding" - Symbol characters
        "\n"       - Integer encoded (5)
        "UTF-8"    - String characters
        "\x06"     - Integer encoded (1)
        ":"        - Symbol beginning
        "\x06"     - Integer encoded (1)
        "E"        - Symbol characters
        "F"        - false
      STR
    end

    it 'returns tokens for dumped BigDecimal' do
      dump = "\x04\bu:\x0FBigDecimal\x0F18:0.314e1"
      expect(Marshal.dump(BigDecimal('3.14'))).to eq dump

      expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
        "\x04\b"   - Version (4.8)
        "u"        - Object with #_dump and .load
        ":"        - Symbol beginning
        "\x0F"     - Integer encoded (10)
        "BigDecimal" - Symbol characters
        "\x0F"     - Integer encoded (10)
        "18:0.314e1" - String characters
      STR
    end

    describe 'subclass of Core Library classes' do
      it 'returns tokens for dumped subclass of Array' do
        dump = "\x04\bC:\x12ArraySubclass[\x00"
        expect(Marshal.dump(ArraySubclass.new)).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          "\x04\b"   - Version (4.8)
          "C"        - Instance of a Core Library class subclass beginning
          ":"        - Symbol beginning
          "\x12"     - Integer encoded (13)
          "ArraySubclass" - Symbol characters
          "["        - Array beginning
          "\x00"     - Integer encoded (0)
        STR
      end

      it 'returns tokens for dumped subclass of String' do
        dump = "\x04\bC:\x13StringSubclass\"\x00"
        expect(Marshal.dump(StringSubclass.new)).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          "\x04\b"   - Version (4.8)
          "C"        - Instance of a Core Library class subclass beginning
          ":"        - Symbol beginning
          "\x13"     - Integer encoded (14)
          "StringSubclass" - Symbol characters
          "\""       - String beginning
          "\x00"     - Integer encoded (0)
          ""         - String characters
        STR
      end

      it 'returns tokens for dumped subclass of Hash' do
        dump = "\x04\bC:\x11HashSubclass{\x00"
        expect(Marshal.dump(HashSubclass.new)).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          "\x04\b"   - Version (4.8)
          "C"        - Instance of a Core Library class subclass beginning
          ":"        - Symbol beginning
          "\x11"     - Integer encoded (12)
          "HashSubclass" - Symbol characters
          "{"        - Hash beginning
          "\x00"     - Integer encoded (0)
        STR
      end

      it 'returns tokens for dumped subclass of Regexp' do
        dump = "\x04\bIC:\x13RegexpSubclass/\babc\x00\x06:\x06EF"
        expect(Marshal.dump(RegexpSubclass.new('abc'))).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          "\x04\b"   - Version (4.8)
          "I"        - Special object with instance variables
          "C"        - Instance of a Core Library class subclass beginning
          ":"        - Symbol beginning
          "\x13"     - Integer encoded (14)
          "RegexpSubclass" - Symbol characters
          "/"        - Regexp beginning
          "\b"       - Integer encoded (3)
          "abc"      - String characters
          "\x00"     - Integer encoded (0)
          "\x06"     - Integer encoded (1)
          ":"        - Symbol beginning
          "\x06"     - Integer encoded (1)
          "E"        - Symbol characters
          "F"        - false
        STR
      end
    end

    describe 'object' do
      it 'returns tokens for dumped object' do
        dump = "\x04\bo:\vObject\x00"
        expect(Marshal.dump(Object.new)).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          "\x04\b"   - Version (4.8)
          "o"        - Object beginning
          ":"        - Symbol beginning
          "\v"       - Integer encoded (6)
          "Object"   - Symbol characters
          "\x00"     - Integer encoded (0)
        STR
      end

      it 'returns tokens for dumped object with instance variables' do
        dump = "\x04\bo:\vObject\x06:\t@fooi\x00"

        object = Object.new
        object.instance_variable_set(:@foo, 0)
        expect(Marshal.dump(object)).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          "\x04\b"   - Version (4.8)
          "o"        - Object beginning
          ":"        - Symbol beginning
          "\v"       - Integer encoded (6)
          "Object"   - Symbol characters
          "\x06"     - Integer encoded (1)
          ":"        - Symbol beginning
          "\t"       - Integer encoded (4)
          "@foo"     - Symbol characters
          "i"        - Integer beginning
          "\x00"     - Integer encoded (0)
        STR
      end

      it 'returns tokens for dumped object with duplicates' do
        dump = "\x04\b[\bo:\vObject\x00T@\x06"
        object = Object.new
        expect(Marshal.dump([object, true, object])).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          "\x04\b"   - Version (4.8)
          "["        - Array beginning
          "\b"       - Integer encoded (3)
          "o"        - Object beginning
          ":"        - Symbol beginning
          "\v"       - Integer encoded (6)
          "Object"   - Symbol characters
          "\x00"     - Integer encoded (0)
          "T"        - true
          "@"        - Link to object
          "\x06"     - Integer encoded (1)
        STR
      end

      it 'returns tokens for dumped object with #_dump method' do
        dump = "\x04\bIu:\x10UserDefined\b1:2\x06:\x06ET"
        expect(Marshal.dump(UserDefined.new(1, 2))).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          "\x04\b"   - Version (4.8)
          "I"        - Special object with instance variables
          "u"        - Object with #_dump and .load
          ":"        - Symbol beginning
          "\x10"     - Integer encoded (11)
          "UserDefined" - Symbol characters
          "\b"       - Integer encoded (3)
          "1:2"      - String characters
          "\x06"     - Integer encoded (1)
          ":"        - Symbol beginning
          "\x06"     - Integer encoded (1)
          "E"        - Symbol characters
          "T"        - true
        STR
      end

      it 'returns tokens for dumped object with #marshal_dump method' do
        dump = "\x04\bU:\x10UserMarshal[\ai\x06i\a"
        expect(Marshal.dump(UserMarshal.new(1, 2))).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          "\x04\b"   - Version (4.8)
          "U"        - Object with #marshal_dump and #marshal_load
          ":"        - Symbol beginning
          "\x10"     - Integer encoded (11)
          "UserMarshal" - Symbol characters
          "["        - Array beginning
          "\a"       - Integer encoded (2)
          "i"        - Integer beginning
          "\x06"     - Integer encoded (1)
          "i"        - Integer beginning
          "\a"       - Integer encoded (2)
        STR
      end

      it 'returns tokens for dumped object extended with a module' do
        dump = "\x04\be:\x0FComparableo:\vObject\x00"

        object = Object.new
        object.extend(Comparable)
        expect(Marshal.dump(object)).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          "\x04\b"   - Version (4.8)
          "e"        - Object extended with a module
          ":"        - Symbol beginning
          "\x0F"     - Integer encoded (10)
          "Comparable" - Symbol characters
          "o"        - Object beginning
          ":"        - Symbol beginning
          "\v"       - Integer encoded (6)
          "Object"   - Symbol characters
          "\x00"     - Integer encoded (0)
        STR
      end
    end
  end
end
