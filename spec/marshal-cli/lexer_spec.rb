# frozen_string_literal: true

RSpec.describe MarshalParser::Lexer do
  describe "#tokens" do
    Lexer = described_class

    def string_to_tokens(string)
      lexer = MarshalParser::Lexer.new(string)
      lexer.run
      lexer.tokens
    end

    it "returns tokens for dumped true" do
      dump = "\x04\bT"
      expect(Marshal.dump(true)).to eq dump

      expect(string_to_tokens(dump)).to eq [
        Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),
        Lexer::Token.new(Lexer::TRUE, 2, 1)
      ]
    end

    it "returns tokens for dumped false" do
      dump = "\x04\bF"
      expect(Marshal.dump(false)).to eq dump

      expect(string_to_tokens(dump)).to eq [
        Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),
        Lexer::Token.new(Lexer::FALSE, 2, 1)
      ]
    end

    it "returns tokens for dumped nil" do
      dump = "\x04\b0"
      expect(Marshal.dump(nil)).to eq dump

      expect(string_to_tokens(dump)).to eq [
        Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),
        Lexer::Token.new(Lexer::NIL, 2, 1, nil)
      ]
    end

    describe "Integer" do
      it "returns tokens for dumped 0" do
        dump = "\x04\bi\x00".b
        expect(Marshal.dump(0)).to eq dump

        expect(string_to_tokens(dump)).to eq [
          Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),

          Lexer::Token.new(Lexer::INTEGER_PREFIX, 2, 1),
          Lexer::Token.new(Lexer::INTEGER, 3, 1, 0)
        ]
      end

      it "returns tokens for dumped 5..122 (a sign-extended eight-bit value with an offset)" do
        dump = "\x04\bi\x7F".b
        expect(Marshal.dump(122)).to eq dump

        expect(string_to_tokens(dump)).to eq [
          Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),

          Lexer::Token.new(Lexer::INTEGER_PREFIX, 2, 1),
          Lexer::Token.new(Lexer::INTEGER, 3, 1, 122)
        ]
      end

      it "returns tokens for dumped -122..-5 (a sign-extended eight-bit value with an offset)" do
        dump = "\x04\bi\x81".b
        expect(Marshal.dump(-122)).to eq dump

        expect(string_to_tokens(dump)).to eq [
          Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),

          Lexer::Token.new(Lexer::INTEGER_PREFIX, 2, 1),
          Lexer::Token.new(Lexer::INTEGER, 3, 1, -122)
        ]
      end

      it "returns tokens for dumped 123..255 (0x01 + the following byte is a positive integer)" do
        dump = "\x04\bi\x01\xFF".b
        expect(Marshal.dump(255)).to eq dump

        expect(string_to_tokens(dump)).to eq [
          Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),

          Lexer::Token.new(Lexer::INTEGER_PREFIX, 2, 1),
          Lexer::Token.new(Lexer::INTEGER, 3, 2, 255)
        ]
      end

      it "returns tokens for dumped -256..-124 (0xFF + the following byte is a negative integer)" do
        dump = "\x04\bi\xFF\x01".b
        expect(Marshal.dump(-255)).to eq dump

        expect(string_to_tokens(dump)).to eq [
          Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),

          Lexer::Token.new(Lexer::INTEGER_PREFIX, 2, 1),
          Lexer::Token.new(Lexer::INTEGER, 3, 2, -255)
        ]
      end

      it "returns tokens for dumped XX XX (0x02 + the following 2 bytes is a positive little-endian integer)" do
        dump = "\x04\bi\x024\x12".b
        expect(Marshal.dump(0x1234)).to eq dump

        expect(string_to_tokens(dump)).to eq [
          Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),

          Lexer::Token.new(Lexer::INTEGER_PREFIX, 2, 1),
          Lexer::Token.new(Lexer::INTEGER, 3, 3, 0x1234)
        ]
      end

      it "returns tokens for dumped -XX XX (0xFE + the following 2 bytes is a negative little-endian integer)" do
        dump = "\x04\bi\xFE\xCC\xED".b
        expect(Marshal.dump(-0x1234)).to eq dump

        expect(string_to_tokens(dump)).to eq [
          Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),

          Lexer::Token.new(Lexer::INTEGER_PREFIX, 2, 1),
          Lexer::Token.new(Lexer::INTEGER, 3, 3, -0x1234)
        ]
      end

      it "returns tokens for dumped XX XX XX (0x03 + the following 3 bytes is a positive little-endian integer)" do
        dump = "\x04\bi\x03V4\x12".b
        expect(Marshal.dump(0x123456)).to eq dump

        expect(string_to_tokens(dump)).to eq [
          Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),

          Lexer::Token.new(Lexer::INTEGER_PREFIX, 2, 1),
          Lexer::Token.new(Lexer::INTEGER, 3, 4, 0x123456)
        ]
      end

      it "returns tokens for dumped -XX XX XX (0xFD + the following 3 bytes is a negative little-endian integer)" do
        dump = "\x04\bi\xFD\xAA\xCB\xED".b
        expect(Marshal.dump(-0x123456)).to eq dump

        expect(string_to_tokens(dump)).to eq [
          Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),

          Lexer::Token.new(Lexer::INTEGER_PREFIX, 2, 1),
          Lexer::Token.new(Lexer::INTEGER, 3, 4, -0x123456)
        ]
      end

      it "returns tokens for dumped XX XX XX XX (0x04 + the following 4 bytes is a positive little-endian integer)" do
        dump = "\x04\bi\x04xV4\x12".b
        expect(Marshal.dump(0x12345678)).to eq dump

        expect(string_to_tokens(dump)).to eq [
          Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),

          Lexer::Token.new(Lexer::INTEGER_PREFIX, 2, 1),
          Lexer::Token.new(Lexer::INTEGER, 3, 5, 0x12345678)
        ]
      end

      it "returns tokens for dumped -XX XX XX XX (0xFC + the following 4 bytes is a negative little-endian integer)" do
        dump = "\x04\bi\xFC\x88\xA9\xCB\xED".b
        expect(Marshal.dump(-0x12345678)).to eq dump

        expect(string_to_tokens(dump)).to eq [
          Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),

          Lexer::Token.new(Lexer::INTEGER_PREFIX, 2, 1),
          Lexer::Token.new(Lexer::INTEGER, 3, 5, -0x12345678)
        ]
      end

      it "returns tokens for dumped positive big Integer (Bignum, > 2^32)" do
        dump = "\x04\bl+\b\x01\x00\x00\x00\x01\x00".b
        expect(Marshal.dump(2.pow(32) + 1)).to eq dump

        expect(string_to_tokens(dump)).to eq [
          Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),

          Lexer::Token.new(Lexer::BIG_INTEGER_PREFIX, 2, 1),
          Lexer::Token.new(Lexer::PLUS_SIGN, 3, 1),
          Lexer::Token.new(Lexer::INTEGER, 4, 1, 3),
          Lexer::Token.new(Lexer::BIG_INTEGER, 5, 6, 2.pow(32) + 1)
        ]
      end

      it "returns tokens for dumped negative big Integer (Bignum)" do
        dump = "\x04\bl-\b\x01\x00\x00\x00\x01\x00".b
        expect(Marshal.dump(-(2.pow(32)) - 1)).to eq dump

        expect(string_to_tokens(dump)).to eq [
          Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),

          Lexer::Token.new(Lexer::BIG_INTEGER_PREFIX, 2, 1),
          Lexer::Token.new(Lexer::MINUS_SIGN, 3, 1),
          Lexer::Token.new(Lexer::INTEGER, 4, 1, 3),
          Lexer::Token.new(Lexer::BIG_INTEGER, 5, 6, -(2.pow(32)) - 1)
        ]
      end
    end

    it "returns tokens for dumped Float" do
      dump = "\x04\bf\t3.14"
      expect(Marshal.dump(3.14)).to eq dump

      expect(string_to_tokens(dump)).to eq [
        Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),
        Lexer::Token.new(Lexer::FLOAT_PREFIX, 2, 1),
        Lexer::Token.new(Lexer::INTEGER, 3, 1, 4),
        Lexer::Token.new(Lexer::FLOAT, 4, 4, 3.14)
      ]
    end

    it "returns tokens for dumped Rational" do
      dump = "\x04\bU:\rRational[\ai\x06i\a"
      expect(Marshal.dump(Rational(1, 2))).to eq dump

      expect(string_to_tokens(dump)).to eq [
        Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),

        Lexer::Token.new(Lexer::OBJECT_WITH_MARSHAL_DUMP_PREFIX, 2, 1),
        Lexer::Token.new(Lexer::SYMBOL_PREFIX, 3, 1),
        Lexer::Token.new(Lexer::INTEGER, 4, 1, 8),
        Lexer::Token.new(Lexer::SYMBOL, 5, 8),

        Lexer::Token.new(Lexer::ARRAY_PREFIX, 13, 1),
        Lexer::Token.new(Lexer::INTEGER, 14, 1, 2),
        Lexer::Token.new(Lexer::INTEGER_PREFIX, 15, 1),
        Lexer::Token.new(Lexer::INTEGER, 16, 1, 1),
        Lexer::Token.new(Lexer::INTEGER_PREFIX, 17, 1),
        Lexer::Token.new(Lexer::INTEGER, 18, 1, 2)
      ]
    end

    it "returns tokens for dumped Complex" do
      dump = "\x04\bU:\fComplex[\ai\x06i\a"
      expect(Marshal.dump(Complex(1, 2))).to eq dump

      expect(string_to_tokens(dump)).to eq [
        Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),

        Lexer::Token.new(Lexer::OBJECT_WITH_MARSHAL_DUMP_PREFIX, 2, 1),
        Lexer::Token.new(Lexer::SYMBOL_PREFIX, 3, 1),
        Lexer::Token.new(Lexer::INTEGER, 4, 1, 7),
        Lexer::Token.new(Lexer::SYMBOL, 5, 7),

        Lexer::Token.new(Lexer::ARRAY_PREFIX, 12, 1),
        Lexer::Token.new(Lexer::INTEGER, 13, 1, 2),
        Lexer::Token.new(Lexer::INTEGER_PREFIX, 14, 1),
        Lexer::Token.new(Lexer::INTEGER, 15, 1, 1),
        Lexer::Token.new(Lexer::INTEGER_PREFIX, 16, 1),
        Lexer::Token.new(Lexer::INTEGER, 17, 1, 2)
      ]
    end

    it "returns tokens for dumped String" do
      dump = "\x04\bI\"\nHello\x06:\x06ET"
      expect(Marshal.dump("Hello")).to eq dump

      expect(string_to_tokens(dump)).to eq [
        Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),
        Lexer::Token.new(Lexer::OBJECT_WITH_IVARS_PREFIX, 2, 1),
        Lexer::Token.new(Lexer::STRING_PREFIX, 3, 1),
        Lexer::Token.new(Lexer::INTEGER, 4, 1, 5),
        Lexer::Token.new(Lexer::STRING, 5, 5),
        Lexer::Token.new(Lexer::INTEGER, 10, 1, 1),
        Lexer::Token.new(Lexer::SYMBOL_PREFIX, 11, 1),
        Lexer::Token.new(Lexer::INTEGER, 12, 1, 1),
        Lexer::Token.new(Lexer::SYMBOL, 13, 1),
        Lexer::Token.new(Lexer::TRUE, 14, 1)
      ]
    end

    it "returns tokens for dumped Symbol" do
      dump = "\x04\b:\nHello"
      expect(Marshal.dump(:Hello)).to eq dump

      expect(string_to_tokens(dump)).to eq [
        Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),
        Lexer::Token.new(Lexer::SYMBOL_PREFIX, 2, 1),
        Lexer::Token.new(Lexer::INTEGER, 3, 1, 5),
        Lexer::Token.new(Lexer::SYMBOL, 4, 5)
      ]
    end

    it "returns tokens for dumped Symbol when there are duplicates" do
      dump = "\x04\b[\b:\nHello:\nworld;\x00"
      expect(Marshal.dump(%i[Hello world Hello])).to eq dump

      expect(string_to_tokens(dump)).to eq [
        Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),
        Lexer::Token.new(Lexer::ARRAY_PREFIX, 2, 1),
        Lexer::Token.new(Lexer::INTEGER, 3, 1, 3),

        Lexer::Token.new(Lexer::SYMBOL_PREFIX, 4, 1),
        Lexer::Token.new(Lexer::INTEGER, 5, 1, 5),
        Lexer::Token.new(Lexer::SYMBOL, 6, 5),

        Lexer::Token.new(Lexer::SYMBOL_PREFIX, 11, 1),
        Lexer::Token.new(Lexer::INTEGER, 12, 1, 5),
        Lexer::Token.new(Lexer::SYMBOL, 13, 5),

        Lexer::Token.new(Lexer::SYMBOL_LINK_PREFIX, 18, 1),
        Lexer::Token.new(Lexer::INTEGER, 19, 1, 0)
      ]
    end

    it "returns tokens for dumped Array" do
      dump = "\x04\b[\aTF"
      expect(Marshal.dump([true, false])).to eq dump

      expect(string_to_tokens(dump)).to eq [
        Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),
        Lexer::Token.new(Lexer::ARRAY_PREFIX, 2, 1),
        Lexer::Token.new(Lexer::INTEGER, 3, 1, 2),
        Lexer::Token.new(Lexer::TRUE, 4, 1),
        Lexer::Token.new(Lexer::FALSE, 5, 1)
      ]
    end

    describe "Hash" do
      it "returns tokens for dumped Hash" do
        dump = "\x04\b{\x06:\x06ai\x00"
        expect(Marshal.dump({ a: 0 })).to eq dump

        expect(string_to_tokens(dump)).to eq [
          Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),
          Lexer::Token.new(Lexer::HASH_PREFIX, 2, 1),
          Lexer::Token.new(Lexer::INTEGER, 3, 1, 1),
          Lexer::Token.new(Lexer::SYMBOL_PREFIX, 4, 1),
          Lexer::Token.new(Lexer::INTEGER, 5, 1, 1),
          Lexer::Token.new(Lexer::SYMBOL, 6, 1),
          Lexer::Token.new(Lexer::INTEGER_PREFIX, 7, 1),
          Lexer::Token.new(Lexer::INTEGER, 8, 1, 0)
        ]
      end

      it "returns tokens for dumped Hash with default value" do
        dump = "\x04\b}\x00i/"

        hash = Hash.new(42)
        expect(Marshal.dump(hash)).to eq dump

        expect(string_to_tokens(dump)).to eq [
          Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),
          Lexer::Token.new(Lexer::HASH_WITH_DEFAULT_VALUE_PREFIX, 2, 1),
          Lexer::Token.new(Lexer::INTEGER, 3, 1, 0),
          Lexer::Token.new(Lexer::INTEGER_PREFIX, 4, 1),
          Lexer::Token.new(Lexer::INTEGER, 5, 1, 42)
        ]
      end

      it "returns tokens for dumped Hash with compare-by-identity behaviour" do
        dump = "\x04\bC:\tHash{\x00"

        hash = {}
        hash.compare_by_identity
        expect(Marshal.dump(hash)).to eq dump

        expect(string_to_tokens(dump)).to eq [
          Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),
          Lexer::Token.new(Lexer::SUBCLASS_OF_CORE_LIBRARY_CLASS_PREFIX, 2, 1),
          Lexer::Token.new(Lexer::SYMBOL_PREFIX, 3, 1),
          Lexer::Token.new(Lexer::INTEGER, 4, 1, 4),
          Lexer::Token.new(Lexer::SYMBOL, 5, 4),
          Lexer::Token.new(Lexer::HASH_PREFIX, 9, 1),
          Lexer::Token.new(Lexer::INTEGER, 10, 1, 0)
        ]
      end
    end

    it "returns tokens for dumped Range" do
      dump = "\x04\bo:\nRange\b:\texclF:\nbegini\x00:\bendi/"

      expect(Marshal.dump(0..42)).to eq dump

      expect(string_to_tokens(dump)).to eq [
        Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),

        Lexer::Token.new(Lexer::OBJECT_PREFIX, 2, 1),
        Lexer::Token.new(Lexer::SYMBOL_PREFIX, 3, 1),
        Lexer::Token.new(Lexer::INTEGER, 4, 1, 5),
        Lexer::Token.new(Lexer::SYMBOL, 5, 5),
        Lexer::Token.new(Lexer::INTEGER, 10, 1, 3),

        Lexer::Token.new(Lexer::SYMBOL_PREFIX, 11, 1),
        Lexer::Token.new(Lexer::INTEGER, 12, 1, 4),
        Lexer::Token.new(Lexer::SYMBOL, 13, 4),
        Lexer::Token.new(Lexer::FALSE, 17, 1),

        Lexer::Token.new(Lexer::SYMBOL_PREFIX, 18, 1),
        Lexer::Token.new(Lexer::INTEGER, 19, 1, 5),
        Lexer::Token.new(Lexer::SYMBOL, 20, 5),
        Lexer::Token.new(Lexer::INTEGER_PREFIX, 25, 1),
        Lexer::Token.new(Lexer::INTEGER, 26, 1, 0),

        Lexer::Token.new(Lexer::SYMBOL_PREFIX, 27, 1),
        Lexer::Token.new(Lexer::INTEGER, 28, 1, 3),
        Lexer::Token.new(Lexer::SYMBOL, 29, 3),
        Lexer::Token.new(Lexer::INTEGER_PREFIX, 32, 1),
        Lexer::Token.new(Lexer::INTEGER, 33, 1, 42)
      ]
    end

    it "returns tokens for dumped Regexp" do
      dump = "\x04\bI/\babc\x00\x06:\x06EF"

      expect(Marshal.dump(/abc/)).to eq dump

      expect(string_to_tokens(dump)).to eq [
        Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),

        Lexer::Token.new(Lexer::OBJECT_WITH_IVARS_PREFIX, 2, 1),
        Lexer::Token.new(Lexer::REGEXP_PREFIX, 3, 1),
        Lexer::Token.new(Lexer::INTEGER, 4, 1, 3),
        Lexer::Token.new(Lexer::STRING, 5, 3),
        Lexer::Token.new(Lexer::BYTE, 8, 1, 0),
        Lexer::Token.new(Lexer::INTEGER, 9, 1, 1),

        Lexer::Token.new(Lexer::SYMBOL_PREFIX, 10, 1),
        Lexer::Token.new(Lexer::INTEGER, 11, 1, 1),
        Lexer::Token.new(Lexer::SYMBOL, 12, 1),
        Lexer::Token.new(Lexer::FALSE, 13, 1)
      ]
    end

    describe "Time" do
      it "returns tokens for dumped Time" do
        dump = "\x04\bIu:\tTime\ri\xC7\x1E\x80\x00\x00\xE0\xCD\a:\voffseti\x020*:\tzone0"

        time = Time.new(2023, 2, 27, 12, 51, 30, "+03:00")
        expect(Marshal.dump(time)).to eq dump.b

        expect(string_to_tokens(dump)).to eq [
          Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),
          Lexer::Token.new(Lexer::OBJECT_WITH_IVARS_PREFIX, 2, 1),
          Lexer::Token.new(Lexer::OBJECT_WITH_DUMP_PREFIX, 3, 1),
          Lexer::Token.new(Lexer::SYMBOL_PREFIX, 4, 1),
          Lexer::Token.new(Lexer::INTEGER, 5, 1, 4),
          Lexer::Token.new(Lexer::SYMBOL, 6, 4),
          Lexer::Token.new(Lexer::INTEGER, 10, 1, 8),
          Lexer::Token.new(Lexer::STRING, 11, 8),
          Lexer::Token.new(Lexer::INTEGER, 19, 1, 2),
          Lexer::Token.new(Lexer::SYMBOL_PREFIX, 20, 1),
          Lexer::Token.new(Lexer::INTEGER, 21, 1, 6),
          Lexer::Token.new(Lexer::SYMBOL, 22, 6),
          Lexer::Token.new(Lexer::INTEGER_PREFIX, 28, 1),
          Lexer::Token.new(Lexer::INTEGER, 29, 3, 10_800),

          Lexer::Token.new(Lexer::SYMBOL_PREFIX, 32, 1),
          Lexer::Token.new(Lexer::INTEGER, 33, 1, 4),
          Lexer::Token.new(Lexer::SYMBOL, 34, 4),
          Lexer::Token.new(Lexer::NIL, 38, 1, nil)
        ]
      end

      it "returns tokens for dumped Time in UTC" do
        dump = "\x04\bIu:\tTime\rl\xC7\x1E\xC0,\x01\xE0\xCD\x06:\tzoneI\"\bUTC\x06:\x06EF"

        time = Time.utc(2023, 2, 27, 12, 51, 30, "+0300")
        expect(Marshal.dump(time)).to eq dump.b

        expect(string_to_tokens(dump)).to eq [
          Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),
          Lexer::Token.new(Lexer::OBJECT_WITH_IVARS_PREFIX, 2, 1),
          Lexer::Token.new(Lexer::OBJECT_WITH_DUMP_PREFIX, 3, 1),
          Lexer::Token.new(Lexer::SYMBOL_PREFIX, 4, 1),
          Lexer::Token.new(Lexer::INTEGER, 5, 1, 4),
          Lexer::Token.new(Lexer::SYMBOL, 6, 4),
          Lexer::Token.new(Lexer::INTEGER, 10, 1, 8),
          Lexer::Token.new(Lexer::STRING, 11, 8),
          Lexer::Token.new(Lexer::INTEGER, 19, 1, 1),
          Lexer::Token.new(Lexer::SYMBOL_PREFIX, 20, 1),
          Lexer::Token.new(Lexer::INTEGER, 21, 1, 4),
          Lexer::Token.new(Lexer::SYMBOL, 22, 4),
          Lexer::Token.new(Lexer::OBJECT_WITH_IVARS_PREFIX, 26, 1),
          Lexer::Token.new(Lexer::STRING_PREFIX, 27, 1),
          Lexer::Token.new(Lexer::INTEGER, 28, 1, 3),
          Lexer::Token.new(Lexer::STRING, 29, 3),
          Lexer::Token.new(Lexer::INTEGER, 32, 1, 1),
          Lexer::Token.new(Lexer::SYMBOL_PREFIX, 33, 1),
          Lexer::Token.new(Lexer::INTEGER, 34, 1, 1),
          Lexer::Token.new(Lexer::SYMBOL, 35, 1),
          Lexer::Token.new(Lexer::FALSE, 36, 1)
        ]
      end
    end

    it "returns tokens for dumped Class" do
      dump = "\x04\bc\vString"
      expect(Marshal.dump(String)).to eq dump

      expect(string_to_tokens(dump)).to eq [
        Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),
        Lexer::Token.new(Lexer::CLASS_PREFIX, 2, 1),
        Lexer::Token.new(Lexer::INTEGER, 3, 1, 6),
        Lexer::Token.new(Lexer::STRING, 4, 6)
      ]
    end

    it "returns tokens for dumped Module" do
      dump = "\x04\bm\x0FEnumerable"
      expect(Marshal.dump(Enumerable)).to eq dump

      expect(string_to_tokens(dump)).to eq [
        Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),
        Lexer::Token.new(Lexer::MODULE_PREFIX, 2, 1),
        Lexer::Token.new(Lexer::INTEGER, 3, 1, 10),
        Lexer::Token.new(Lexer::STRING, 4, 10)
      ]
    end

    it "returns tokens for dumped Struct" do
      dump = "\x04\bS:\fStructA\x06:\x06ai\x06"
      expect(Marshal.dump(StructA.new(1))).to eq dump

      expect(string_to_tokens(dump)).to eq [
        Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),

        Lexer::Token.new(Lexer::STRUCT_PREFIX, 2, 1),
        Lexer::Token.new(Lexer::SYMBOL_PREFIX, 3, 1),
        Lexer::Token.new(Lexer::INTEGER, 4, 1, 7),
        Lexer::Token.new(Lexer::SYMBOL, 5, 7),
        Lexer::Token.new(Lexer::INTEGER, 12, 1, 1),

        Lexer::Token.new(Lexer::SYMBOL_PREFIX, 13, 1),
        Lexer::Token.new(Lexer::INTEGER, 14, 1, 1),
        Lexer::Token.new(Lexer::SYMBOL, 15, 1),

        Lexer::Token.new(Lexer::INTEGER_PREFIX, 16, 1),
        Lexer::Token.new(Lexer::INTEGER, 17, 1, 1)
      ]
    end

    it "returns tokens for dumped Encoding" do
      dump = "\x04\bIu:\rEncoding\nUTF-8\x06:\x06EF"
      expect(Marshal.dump(Encoding::UTF_8)).to eq dump

      expect(string_to_tokens(dump)).to eq [
        Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),

        Lexer::Token.new(Lexer::OBJECT_WITH_IVARS_PREFIX, 2, 1),
        Lexer::Token.new(Lexer::OBJECT_WITH_DUMP_PREFIX, 3, 1),
        Lexer::Token.new(Lexer::SYMBOL_PREFIX, 4, 1),
        Lexer::Token.new(Lexer::INTEGER, 5, 1, 8),
        Lexer::Token.new(Lexer::SYMBOL, 6, 8),

        Lexer::Token.new(Lexer::INTEGER, 14, 1, 5),
        Lexer::Token.new(Lexer::STRING, 15, 5),
        Lexer::Token.new(Lexer::INTEGER, 20, 1, 1),

        Lexer::Token.new(Lexer::SYMBOL_PREFIX, 21, 1),
        Lexer::Token.new(Lexer::INTEGER, 22, 1, 1),
        Lexer::Token.new(Lexer::SYMBOL, 23, 1),
        Lexer::Token.new(Lexer::FALSE, 24, 1)
      ]
    end

    require "bigdecimal"

    it "returns tokens for dumped BigDecimal" do
      dump = "\x04\bu:\x0FBigDecimal\x0F18:0.314e1"
      expect(Marshal.dump(BigDecimal("3.14"))).to eq dump

      expect(string_to_tokens(dump)).to eq [
        Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),

        Lexer::Token.new(Lexer::OBJECT_WITH_DUMP_PREFIX, 2, 1),
        Lexer::Token.new(Lexer::SYMBOL_PREFIX, 3, 1),
        Lexer::Token.new(Lexer::INTEGER, 4, 1, 10),
        Lexer::Token.new(Lexer::SYMBOL, 5, 10),

        Lexer::Token.new(Lexer::INTEGER, 15, 1, 10),
        Lexer::Token.new(Lexer::STRING, 16, 10)
      ]
    end

    describe "subclass of Core Library classes" do
      it "returns tokens for dumped subclass of Array" do
        dump = "\x04\bC:\x12ArraySubclass[\x00"
        expect(Marshal.dump(ArraySubclass.new)).to eq dump

        expect(string_to_tokens(dump)).to eq [
          Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),
          Lexer::Token.new(Lexer::SUBCLASS_OF_CORE_LIBRARY_CLASS_PREFIX, 2, 1),
          Lexer::Token.new(Lexer::SYMBOL_PREFIX, 3, 1),
          Lexer::Token.new(Lexer::INTEGER, 4, 1, 13),
          Lexer::Token.new(Lexer::SYMBOL, 5, 13),
          Lexer::Token.new(Lexer::ARRAY_PREFIX, 18, 1),
          Lexer::Token.new(Lexer::INTEGER, 19, 1, 0)
        ]
      end

      it "returns tokens for dumped subclass of String" do
        dump = "\x04\bC:\x13StringSubclass\"\x00"
        expect(Marshal.dump(StringSubclass.new)).to eq dump

        expect(string_to_tokens(dump)).to eq [
          Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),
          Lexer::Token.new(Lexer::SUBCLASS_OF_CORE_LIBRARY_CLASS_PREFIX, 2, 1),
          Lexer::Token.new(Lexer::SYMBOL_PREFIX, 3, 1),
          Lexer::Token.new(Lexer::INTEGER, 4, 1, 14),
          Lexer::Token.new(Lexer::SYMBOL, 5, 14),
          Lexer::Token.new(Lexer::STRING_PREFIX, 19, 1),
          Lexer::Token.new(Lexer::INTEGER, 20, 1, 0),
          Lexer::Token.new(Lexer::STRING, 21, 0)
        ]
      end

      it "returns tokens for dumped subclass of Hash" do
        dump = "\x04\bC:\x11HashSubclass{\x00"
        expect(Marshal.dump(HashSubclass.new)).to eq dump

        expect(string_to_tokens(dump)).to eq [
          Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),
          Lexer::Token.new(Lexer::SUBCLASS_OF_CORE_LIBRARY_CLASS_PREFIX, 2, 1),
          Lexer::Token.new(Lexer::SYMBOL_PREFIX, 3, 1),
          Lexer::Token.new(Lexer::INTEGER, 4, 1, 12),
          Lexer::Token.new(Lexer::SYMBOL, 5, 12),
          Lexer::Token.new(Lexer::HASH_PREFIX, 17, 1),
          Lexer::Token.new(Lexer::INTEGER, 18, 1, 0)
        ]
      end

      it "returns tokens for dumped subclass of Regexp" do
        dump = "\x04\bIC:\x13RegexpSubclass/\babc\x00\x06:\x06EF"

        expect(Marshal.dump(RegexpSubclass.new("abc"))).to eq dump

        expect(string_to_tokens(dump)).to eq [
          Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),

          Lexer::Token.new(Lexer::OBJECT_WITH_IVARS_PREFIX, 2, 1),

          Lexer::Token.new(Lexer::SUBCLASS_OF_CORE_LIBRARY_CLASS_PREFIX, 3, 1),
          Lexer::Token.new(Lexer::SYMBOL_PREFIX, 4, 1),
          Lexer::Token.new(Lexer::INTEGER, 5, 1, 14),
          Lexer::Token.new(Lexer::SYMBOL, 6, 14),

          Lexer::Token.new(Lexer::REGEXP_PREFIX, 20, 1),
          Lexer::Token.new(Lexer::INTEGER, 21, 1, 3),
          Lexer::Token.new(Lexer::STRING, 22, 3),
          Lexer::Token.new(Lexer::BYTE, 25, 1, 0),
          Lexer::Token.new(Lexer::INTEGER, 26, 1, 1),

          Lexer::Token.new(Lexer::SYMBOL_PREFIX, 27, 1),
          Lexer::Token.new(Lexer::INTEGER, 28, 1, 1),
          Lexer::Token.new(Lexer::SYMBOL, 29, 1),
          Lexer::Token.new(Lexer::FALSE, 30, 1)
        ]
      end
    end

    describe "object" do
      it "returns tokens for dumped object" do
        dump = "\x04\bo:\vObject\x00"
        expect(Marshal.dump(Object.new)).to eq dump

        expect(string_to_tokens(dump)).to eq [
          Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),
          Lexer::Token.new(Lexer::OBJECT_PREFIX, 2, 1),
          Lexer::Token.new(Lexer::SYMBOL_PREFIX, 3, 1),
          Lexer::Token.new(Lexer::INTEGER, 4, 1, 6),
          Lexer::Token.new(Lexer::SYMBOL, 5, 6),
          Lexer::Token.new(Lexer::INTEGER, 11, 1, 0)
        ]
      end

      it "returns tokens for dumped object with instance variables" do
        dump = "\x04\bo:\vObject\x06:\t@fooi\x00"

        object = Object.new
        object.instance_variable_set(:@foo, 0)
        expect(Marshal.dump(object)).to eq dump

        expect(string_to_tokens(dump)).to eq [
          Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),
          Lexer::Token.new(Lexer::OBJECT_PREFIX, 2, 1),
          Lexer::Token.new(Lexer::SYMBOL_PREFIX, 3, 1),
          Lexer::Token.new(Lexer::INTEGER, 4, 1, 6),
          Lexer::Token.new(Lexer::SYMBOL, 5, 6),
          Lexer::Token.new(Lexer::INTEGER, 11, 1, 1),

          Lexer::Token.new(Lexer::SYMBOL_PREFIX, 12, 1),
          Lexer::Token.new(Lexer::INTEGER, 13, 1, 4),
          Lexer::Token.new(Lexer::SYMBOL, 14, 4),
          Lexer::Token.new(Lexer::INTEGER_PREFIX, 18, 1),
          Lexer::Token.new(Lexer::INTEGER, 19, 1, 0)
        ]
      end

      it "returns tokens for dumped object with duplicates" do
        dump = "\x04\b[\bo:\vObject\x00T@\x06"
        object = Object.new
        expect(Marshal.dump([object, true, object])).to eq dump

        expect(string_to_tokens(dump)).to eq [
          Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),
          Lexer::Token.new(Lexer::ARRAY_PREFIX, 2, 1),
          Lexer::Token.new(Lexer::INTEGER, 3, 1, 3),

          Lexer::Token.new(Lexer::OBJECT_PREFIX, 4, 1),
          Lexer::Token.new(Lexer::SYMBOL_PREFIX, 5, 1),
          Lexer::Token.new(Lexer::INTEGER, 6, 1, 6),
          Lexer::Token.new(Lexer::SYMBOL, 7, 6),
          Lexer::Token.new(Lexer::INTEGER, 13, 1, 0),

          Lexer::Token.new(Lexer::TRUE, 14, 1),

          Lexer::Token.new(Lexer::OBJECT_LINK_PREFIX, 15, 1),
          Lexer::Token.new(Lexer::INTEGER, 16, 1, 1)
        ]
      end

      it "returns tokens for dumped object with #_dump method" do
        dump = "\x04\bIu:\x10UserDefined\b1:2\x06:\x06ET"

        expect(Marshal.dump(UserDefined.new(1, 2))).to eq dump

        expect(string_to_tokens(dump)).to eq [
          Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),
          Lexer::Token.new(Lexer::OBJECT_WITH_IVARS_PREFIX, 2, 1),
          Lexer::Token.new(Lexer::OBJECT_WITH_DUMP_PREFIX, 3, 1),
          Lexer::Token.new(Lexer::SYMBOL_PREFIX, 4, 1),
          Lexer::Token.new(Lexer::INTEGER, 5, 1, 11),
          Lexer::Token.new(Lexer::SYMBOL, 6, 11),
          Lexer::Token.new(Lexer::INTEGER, 17, 1, 3),
          Lexer::Token.new(Lexer::STRING, 18, 3),
          Lexer::Token.new(Lexer::INTEGER, 21, 1, 1),
          Lexer::Token.new(Lexer::SYMBOL_PREFIX, 22, 1),
          Lexer::Token.new(Lexer::INTEGER, 23, 1, 1),
          Lexer::Token.new(Lexer::SYMBOL, 24, 1),
          Lexer::Token.new(Lexer::TRUE, 25, 1)
        ]
      end

      it "returns tokens for dumped object with #marshal_dump method" do
        dump = "\x04\bU:\x10UserMarshal[\ai\x06i\a"
        expect(Marshal.dump(UserMarshal.new(1, 2))).to eq dump

        expect(string_to_tokens(dump)).to eq [
          Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),
          Lexer::Token.new(Lexer::OBJECT_WITH_MARSHAL_DUMP_PREFIX, 2, 1),
          Lexer::Token.new(Lexer::SYMBOL_PREFIX, 3, 1),
          Lexer::Token.new(Lexer::INTEGER, 4, 1, 11),
          Lexer::Token.new(Lexer::SYMBOL, 5, 11),
          Lexer::Token.new(Lexer::ARRAY_PREFIX, 16, 1),
          Lexer::Token.new(Lexer::INTEGER, 17, 1, 2),
          Lexer::Token.new(Lexer::INTEGER_PREFIX, 18, 1),
          Lexer::Token.new(Lexer::INTEGER, 19, 1, 1),
          Lexer::Token.new(Lexer::INTEGER_PREFIX, 20, 1),
          Lexer::Token.new(Lexer::INTEGER, 21, 1, 2)
        ]
      end

      it "returns tokens for dumped object extended with a module" do
        dump = "\x04\be:\x0FComparableo:\vObject\x00"

        object = Object.new
        object.extend(Comparable)
        expect(Marshal.dump(object)).to eq dump

        expect(string_to_tokens(dump)).to eq [
          Lexer::Token.new(Lexer::VERSION, 0, 2, "4.8"),
          Lexer::Token.new(Lexer::OBJECT_EXTENDED_PREFIX, 2, 1),
          Lexer::Token.new(Lexer::SYMBOL_PREFIX, 3, 1),
          Lexer::Token.new(Lexer::INTEGER, 4, 1, 10),
          Lexer::Token.new(Lexer::SYMBOL, 5, 10),
          Lexer::Token.new(Lexer::OBJECT_PREFIX, 15, 1),
          Lexer::Token.new(Lexer::SYMBOL_PREFIX, 16, 1),
          Lexer::Token.new(Lexer::INTEGER, 17, 1, 6),
          Lexer::Token.new(Lexer::SYMBOL, 18, 6),
          Lexer::Token.new(Lexer::INTEGER, 24, 1, 0)
        ]
      end
    end
  end
end
