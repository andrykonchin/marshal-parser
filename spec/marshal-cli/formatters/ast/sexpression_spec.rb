# frozen_string_literal: true

require "bigdecimal"

RSpec.describe MarshalParser::Formatters::AST::SExpression do
  describe "#string" do
    def formatted_output(source_string)
      lexer = MarshalParser::Lexer.new(source_string)
      lexer.run

      parser = MarshalParser::Parser.new(lexer)
      ast = parser.parse

      renderer = MarshalParser::Formatters::AST::Renderers::Renderer.new(indent_size: 2)
      formatter = described_class.new(ast, source_string, renderer)
      formatter.string
    end

    it "returns tokens for dumped true" do
      dump = "\x04\bT"
      expect(Marshal.dump(true)).to eq dump

      expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
        (true)
      STR
    end

    it "returns tokens for dumped false" do
      dump = "\x04\bF"
      expect(Marshal.dump(false)).to eq dump

      expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
        (false)
      STR
    end

    it "returns tokens for dumped nil" do
      dump = "\x04\b0"
      expect(Marshal.dump(nil)).to eq dump

      expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
        (nil)
      STR
    end

    describe "Integer" do
      it "returns tokens for dumped 0" do
        dump = "\x04\bi\x00".b
        expect(Marshal.dump(0)).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          (integer
            (value 0))
        STR
      end

      it "returns tokens for dumped 5..122 (a sign-extended eight-bit value with an offset)" do
        dump = "\x04\bi\x7F".b
        expect(Marshal.dump(122)).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          (integer
            (value 122))
        STR
      end

      it "returns tokens for dumped -122..-5 (a sign-extended eight-bit value with an offset)" do
        dump = "\x04\bi\x81".b
        expect(Marshal.dump(-122)).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          (integer
            (value -122))
        STR
      end

      it "returns tokens for dumped 123..255 (0x01 + the following byte is a positive integer)" do
        dump = "\x04\bi\x01\xFF".b
        expect(Marshal.dump(255)).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          (integer
            (value 255))
        STR
      end

      it "returns tokens for dumped -256..-124 (0xFF + the following byte is a negative integer)" do
        dump = "\x04\bi\xFF\x01".b
        expect(Marshal.dump(-255)).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          (integer
            (value -255))
        STR
      end

      it "returns tokens for dumped XX XX (0x02 + the following 2 bytes is a positive little-endian integer)" do
        dump = "\x04\bi\x024\x12".b
        expect(Marshal.dump(0x1234)).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          (integer
            (value 4660))
        STR
      end

      it "returns tokens for dumped -XX XX (0xFE + the following 2 bytes is a negative little-endian integer)" do
        dump = "\x04\bi\xFE\xCC\xED".b
        expect(Marshal.dump(-0x1234)).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          (integer
            (value -4660))
        STR
      end

      it "returns tokens for dumped XX XX XX (0x03 + the following 3 bytes is a positive little-endian integer)" do
        dump = "\x04\bi\x03V4\x12".b
        expect(Marshal.dump(0x123456)).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          (integer
            (value 1193046))
        STR
      end

      it "returns tokens for dumped -XX XX XX (0xFD + the following 3 bytes is a negative little-endian integer)" do
        dump = "\x04\bi\xFD\xAA\xCB\xED".b
        expect(Marshal.dump(-0x123456)).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          (integer
            (value -1193046))
        STR
      end

      it "returns tokens for dumped XX XX XX XX (0x04 + the following 4 bytes is a positive little-endian integer)" do
        dump = "\x04\bi\x04xV4\x12".b
        expect(Marshal.dump(0x12345678)).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          (integer
            (value 305419896))
        STR
      end

      it "returns tokens for dumped -XX XX XX XX (0xFC + the following 4 bytes is a negative little-endian integer)" do
        dump = "\x04\bi\xFC\x88\xA9\xCB\xED".b
        expect(Marshal.dump(-0x12345678)).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          (integer
            (value -305419896))
        STR
      end

      it "returns tokens for dumped positive big Integer (Bignum, > 2^32)" do
        dump = "\x04\bl+\b\x01\x00\x00\x00\x01\x00".b
        expect(Marshal.dump(2.pow(32) + 1)).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          (big-integer
            (value 4294967297))
        STR
      end

      it "returns tokens for dumped negative big Integer (Bignum)" do
        dump = "\x04\bl-\b\x01\x00\x00\x00\x01\x00".b
        expect(Marshal.dump(-(2.pow(32)) - 1)).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          (big-integer
            (value -4294967297))
        STR
      end
    end

    it "returns tokens for dumped Float" do
      dump = "\x04\bf\t3.14"
      expect(Marshal.dump(3.14)).to eq dump

      expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
        (float
          (length 4)
          (value 3.14))
      STR
    end

    it "returns tokens for dumped Rational" do
      dump = "\x04\bU:\rRational[\ai\x06i\a"
      expect(Marshal.dump(Rational(1, 2))).to eq dump

      expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
        (object-with-marshal-dump-method
          (symbol
            (length 8)
            (content "Rational"))
          (array
            (length 2)
            (integer
              (value 1))
            (integer
              (value 2))))
      STR
    end

    it "returns tokens for dumped Complex" do
      dump = "\x04\bU:\fComplex[\ai\x06i\a"
      expect(Marshal.dump(Complex(1, 2))).to eq dump

      expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
        (object-with-marshal-dump-method
          (symbol
            (length 7)
            (content "Complex"))
          (array
            (length 2)
            (integer
              (value 1))
            (integer
              (value 2))))
      STR
    end

    it "returns tokens for dumped String" do
      dump = "\x04\bI\"\nHello\x06:\x06ET"
      expect(Marshal.dump("Hello")).to eq dump

      expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
        (object-with-ivars
          (string
            (length 5)
            (content "Hello"))
          (ivars-count 1)
          (symbol
            (length 1)
            (content "E"))
          (true))
      STR
    end

    it "returns tokens for dumped Symbol" do
      dump = "\x04\b:\nHello"
      expect(Marshal.dump(:Hello)).to eq dump

      expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
        (symbol
          (length 5)
          (content "Hello"))
      STR
    end

    it "returns tokens for dumped Symbol when there are duplicates" do
      dump = "\x04\b[\b:\nHello:\nworld;\x00"
      expect(Marshal.dump(%i[Hello world Hello])).to eq dump

      expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
        (array
          (length 3)
          (symbol
            (length 5)
            (content "Hello"))
          (symbol
            (length 5)
            (content "world"))
          (symbol-link
            (index 0)))
      STR
    end

    it "returns tokens for dumped Array" do
      dump = "\x04\b[\aTF"
      expect(Marshal.dump([true, false])).to eq dump

      expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
        (array
          (length 2)
          (true)
          (false))
      STR
    end

    describe "Hash" do
      it "returns tokens for dumped Hash" do
        dump = "\x04\b{\x06:\x06ai\x00"
        expect(Marshal.dump({ a: 0 })).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          (hash
            (size 1)
            (symbol
              (length 1)
              (content "a"))
            (integer
              (value 0)))
        STR
      end

      it "returns tokens for dumped Hash with Integer as default value" do
        dump = "\x04\b}\x00i/"

        hash = Hash.new(42)
        expect(Marshal.dump(hash)).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          (hash-with-default-value
            (size 0)
            (integer
              (value 42)))
        STR
      end

      it "returns tokens for dumped Hash with non-Integer as default value" do
        dump = "\x04\b}\x00:\vfoobar"

        hash = Hash.new(:foobar)
        expect(Marshal.dump(hash)).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          (hash-with-default-value
            (size 0)
            (symbol
              (length 6)
              (content "foobar")))
        STR
      end

      it "returns tokens for dumped Hash with compare-by-identity behaviour" do
        dump = "\x04\bC:\tHash{\x00"

        hash = {}
        hash.compare_by_identity
        expect(Marshal.dump(hash)).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          (subclass
            (symbol
              (length 4)
              (content "Hash"))
            (hash
              (size 0)))
        STR
      end
    end

    it "returns tokens for dumped Range" do
      dump = "\x04\bo:\nRange\b:\texclF:\nbegini\x00:\bendi/"
      expect(Marshal.dump(0..42)).to eq dump

      expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
        (object
          (symbol
            (length 5)
            (content "Range"))
          (ivars-count 3)
          (symbol
            (length 4)
            (content "excl"))
          (false)
          (symbol
            (length 5)
            (content "begin"))
          (integer
            (value 0))
          (symbol
            (length 3)
            (content "end"))
          (integer
            (value 42)))
      STR
    end

    it "returns tokens for dumped Regexp" do
      dump = "\x04\bI/\babc\x00\x06:\x06EF"
      expect(Marshal.dump(/abc/)).to eq dump

      expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
        (object-with-ivars
          (regexp
            (length 3)
            (source-string "abc")
            (options 0))
          (ivars-count 1)
          (symbol
            (length 1)
            (content "E"))
          (false))
      STR
    end

    describe "Time" do
      it "returns tokens for dumped Time" do
        dump = "\x04\bIu:\tTime\ri\xC7\x1E\x80\x00\x00\xE0\xCD\a:\voffseti\x020*:\tzone0".b

        time = Time.new(2023, 2, 27, 12, 51, 30, "+03:00")
        expect(Marshal.dump(time)).to eq dump.b

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          (object-with-ivars
            (object-with-dump-method
              (symbol
                (length 4)
                (content "Time"))
              (length 8)
              (dump "i\xC7\x1E\x80\x00\x00\xE0\xCD"))
            (ivars-count 2)
            (symbol
              (length 6)
              (content "offset"))
            (integer
              (value 10800))
            (symbol
              (length 4)
              (content "zone"))
            (nil))
        STR
      end

      it "returns tokens for dumped Time in UTC" do
        dump = "\x04\bIu:\tTime\rl\xC7\x1E\xC0,\x01\xE0\xCD\x06:\tzoneI\"\bUTC\x06:\x06EF".b

        time = Time.utc(2023, 2, 27, 12, 51, 30, "+0300")
        expect(Marshal.dump(time)).to eq dump.b

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          (object-with-ivars
            (object-with-dump-method
              (symbol
                (length 4)
                (content "Time"))
              (length 8)
              (dump "l\xC7\x1E\xC0,\x01\xE0\xCD"))
            (ivars-count 1)
            (symbol
              (length 4)
              (content "zone"))
            (object-with-ivars
              (string
                (length 3)
                (content "UTC"))
              (ivars-count 1)
              (symbol
                (length 1)
                (content "E"))
              (false)))
        STR
      end
    end

    it "returns tokens for dumped Class" do
      dump = "\x04\bc\vString"
      expect(Marshal.dump(String)).to eq dump

      expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
        (class
          (length 6)
          (name "String"))
      STR
    end

    it "returns tokens for dumped Module" do
      dump = "\x04\bm\x0FEnumerable"
      expect(Marshal.dump(Enumerable)).to eq dump

      expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
        (module
          (length 10)
          (name "Enumerable"))
      STR
    end

    it "returns tokens for dumped Struct" do
      dump = "\x04\bS:\fStructA\x06:\x06ai\x06"
      expect(Marshal.dump(StructA.new(1))).to eq dump

      expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
        (struct
          (symbol
            (length 7)
            (content "StructA"))
          (count 1)
          (symbol
            (length 1)
            (content "a"))
          (integer
            (value 1)))
      STR
    end

    it "returns tokens for dumped Encoding" do
      dump = "\x04\bIu:\rEncoding\nUTF-8\x06:\x06EF"
      expect(Marshal.dump(Encoding::UTF_8)).to eq dump

      expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
        (object-with-ivars
          (object-with-dump-method
            (symbol
              (length 8)
              (content "Encoding"))
            (length 5)
            (dump "UTF-8"))
          (ivars-count 1)
          (symbol
            (length 1)
            (content "E"))
          (false))
      STR
    end

    it "returns tokens for dumped BigDecimal" do
      dump = "\x04\bu:\x0FBigDecimal\x0F18:0.314e1"
      expect(Marshal.dump(BigDecimal("3.14"))).to eq dump

      expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
        (object-with-dump-method
          (symbol
            (length 10)
            (content "BigDecimal"))
          (length 10)
          (dump "18:0.314e1"))
      STR
    end

    describe "subclass of Core Library classes" do
      it "returns tokens for dumped subclass of Array" do
        dump = "\x04\bC:\x12ArraySubclass[\x00"
        expect(Marshal.dump(ArraySubclass.new)).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          (subclass
            (symbol
              (length 13)
              (content "ArraySubclass"))
            (array
              (length 0)))
        STR
      end

      it "returns tokens for dumped subclass of String" do
        dump = "\x04\bC:\x13StringSubclass\"\x00"
        expect(Marshal.dump(StringSubclass.new)).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          (subclass
            (symbol
              (length 14)
              (content "StringSubclass"))
            (string
              (length 0)
              (content "")))
        STR
      end

      it "returns tokens for dumped subclass of Hash" do
        dump = "\x04\bC:\x11HashSubclass{\x00"
        expect(Marshal.dump(HashSubclass.new)).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          (subclass
            (symbol
              (length 12)
              (content "HashSubclass"))
            (hash
              (size 0)))
        STR
      end

      it "returns tokens for dumped subclass of Regexp" do
        dump = "\x04\bIC:\x13RegexpSubclass/\babc\x00\x06:\x06EF"
        expect(Marshal.dump(RegexpSubclass.new("abc"))).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          (object-with-ivars
            (subclass
              (symbol
                (length 14)
                (content "RegexpSubclass"))
              (regexp
                (length 3)
                (source-string "abc")
                (options 0)))
            (ivars-count 1)
            (symbol
              (length 1)
              (content "E"))
            (false))
        STR
      end
    end

    describe "object" do
      it "returns tokens for dumped object" do
        dump = "\x04\bo:\vObject\x00"
        expect(Marshal.dump(Object.new)).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          (object
            (symbol
              (length 6)
              (content "Object"))
            (ivars-count 0))
        STR
      end

      it "returns tokens for dumped object with instance variables" do
        dump = "\x04\bo:\vObject\x06:\t@fooi\x00"

        object = Object.new
        object.instance_variable_set(:@foo, 0)
        expect(Marshal.dump(object)).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          (object
            (symbol
              (length 6)
              (content "Object"))
            (ivars-count 1)
            (symbol
              (length 4)
              (content "@foo"))
            (integer
              (value 0)))
        STR
      end

      it "returns tokens for dumped object with duplicates" do
        dump = "\x04\b[\bo:\vObject\x00T@\x06"
        object = Object.new
        expect(Marshal.dump([object, true, object])).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          (array
            (length 3)
            (object
              (symbol
                (length 6)
                (content "Object"))
              (ivars-count 0))
            (true)
            (object-link
              (index 1)))
        STR
      end

      it "returns tokens for dumped object with #_dump method" do
        dump = "\x04\bIu:\x10UserDefined\b1:2\x06:\x06ET"
        expect(Marshal.dump(UserDefined.new(1, 2))).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          (object-with-ivars
            (object-with-dump-method
              (symbol
                (length 11)
                (content "UserDefined"))
              (length 3)
              (dump "1:2"))
            (ivars-count 1)
            (symbol
              (length 1)
              (content "E"))
            (true))
        STR
      end

      it "returns tokens for dumped object with #marshal_dump method" do
        dump = "\x04\bU:\x10UserMarshal[\ai\x06i\a"
        expect(Marshal.dump(UserMarshal.new(1, 2))).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          (object-with-marshal-dump-method
            (symbol
              (length 11)
              (content "UserMarshal"))
            (array
              (length 2)
              (integer
                (value 1))
              (integer
                (value 2))))
        STR
      end

      it "returns tokens for dumped object extended with a module" do
        dump = "\x04\be:\x0FComparableo:\vObject\x00"

        object = Object.new
        object.extend(Comparable)
        expect(Marshal.dump(object)).to eq dump

        expect(formatted_output(dump)).to eq <<~'STR'.b.chomp
          (object-extended
            (symbol
              (length 10)
              (content "Comparable"))
            (object
              (symbol
                (length 6)
                (content "Object"))
              (ivars-count 0)))
        STR
      end
    end
  end
end
