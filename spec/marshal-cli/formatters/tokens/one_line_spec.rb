# frozen_string_literal: true
require 'bigdecimal'

RSpec.describe MarshalCLI::Formatters::Tokens::OneLine do
  describe '#string' do
    def formatted_output(string)
      lexer = MarshalCLI::Lexer.new(string)
      lexer.run
      tokens = lexer.tokens

      formatter = described_class.new(tokens, string)
      formatter.string
    end

    it 'returns tokens for dumped true' do
      dump = "\x04\bT"
      expect(Marshal.dump(true)).to eq dump

      expect(formatted_output(dump)).to eq '"\x04\b" T'.b
    end

    it 'returns tokens for dumped false' do
      dump = "\x04\bF"
      expect(Marshal.dump(false)).to eq dump

      expect(formatted_output(dump)).to eq '"\x04\b" F'.b
    end

    it 'returns tokens for dumped nil' do
      dump = "\x04\b0"
      expect(Marshal.dump(nil)).to eq dump

      expect(formatted_output(dump)).to eq '"\x04\b" 0'.b
    end

    describe 'Integer' do
      it 'returns tokens for dumped 0' do
        dump = "\x04\bi\x00".b
        expect(Marshal.dump(0)).to eq dump

        expect(formatted_output(dump)).to eq '"\x04\b" i "\x00"'.b
      end

      it 'returns tokens for dumped 5..122 (a sign-extended eight-bit value with an offset)' do
        dump = "\x04\bi\x7F".b
        expect(Marshal.dump(122)).to eq dump

        expect(formatted_output(dump)).to eq '"\x04\b" i "\x7F"'.b
      end

      it 'returns tokens for dumped -122..-5 (a sign-extended eight-bit value with an offset)' do
        dump = "\x04\bi\x81".b
        expect(Marshal.dump(-122)).to eq dump

        expect(formatted_output(dump)).to eq '"\x04\b" i "\x81"'.b
      end

      it 'returns tokens for dumped 123..255 (0x01 + the following byte is a positive integer)' do
        dump = "\x04\bi\x01\xFF".b
        expect(Marshal.dump(255)).to eq dump

        expect(formatted_output(dump)).to eq '"\x04\b" i "\x01\xFF"'.b
      end

      it 'returns tokens for dumped -256..-124 (0xFF + the following byte is a negative integer)' do
        dump = "\x04\bi\xFF\x01".b
        expect(Marshal.dump(-255)).to eq dump

        expect(formatted_output(dump)).to eq '"\x04\b" i "\xFF\x01"'.b
      end

      it 'returns tokens for dumped XX XX (0x02 + the following 2 bytes is a positive little-endian integer)' do
        dump = "\x04\bi\x024\x12".b
        expect(Marshal.dump(0x1234)).to eq dump

        expect(formatted_output(dump)).to eq '"\x04\b" i "\x024\x12"'.b
      end

      it 'returns tokens for dumped -XX XX (0xFE + the following 2 bytes is a negative little-endian integer)' do
        dump = "\x04\bi\xFE\xCC\xED".b
        expect(Marshal.dump(-0x1234)).to eq dump

        expect(formatted_output(dump)).to eq '"\x04\b" i "\xFE\xCC\xED"'.b
      end

      it 'returns tokens for dumped XX XX XX (0x03 + the following 3 bytes is a positive little-endian integer)' do
        dump = "\x04\bi\x03V4\x12".b
        expect(Marshal.dump(0x123456)).to eq dump

        expect(formatted_output(dump)).to eq '"\x04\b" i "\x03V4\x12"'.b
      end

      it 'returns tokens for dumped -XX XX XX (0xFD + the following 3 bytes is a negative little-endian integer)' do
        dump = "\x04\bi\xFD\xAA\xCB\xED".b
        expect(Marshal.dump(-0x123456)).to eq dump

        expect(formatted_output(dump)).to eq '"\x04\b" i "\xFD\xAA\xCB\xED"'.b
      end

      it 'returns tokens for dumped XX XX XX XX (0x04 + the following 4 bytes is a positive little-endian integer)' do
        dump = "\x04\bi\x04xV4\x12".b
        expect(Marshal.dump(0x12345678)).to eq dump

        expect(formatted_output(dump)).to eq '"\x04\b" i "\x04xV4\x12"'.b
      end

      it 'returns tokens for dumped -XX XX XX XX (0xFC + the following 4 bytes is a negative little-endian integer)' do
        dump = "\x04\bi\xFC\x88\xA9\xCB\xED".b
        expect(Marshal.dump(-0x12345678)).to eq dump

        expect(formatted_output(dump)).to eq '"\x04\b" i "\xFC\x88\xA9\xCB\xED"'.b
      end

      it 'returns tokens for dumped positive big Integer (Bignum, > 2^32)' do
        dump = "\x04\bl+\b\x01\x00\x00\x00\x01\x00".b
        expect(Marshal.dump(2.pow(32) + 1)).to eq dump

        expect(formatted_output(dump)).to eq '"\x04\b" l + "\b" "\x01\x00\x00\x00\x01\x00"'.b
      end

      it 'returns tokens for dumped negative big Integer (Bignum)' do
        dump = "\x04\bl-\b\x01\x00\x00\x00\x01\x00".b
        expect(Marshal.dump(-(2.pow(32)) - 1)).to eq dump

        expect(formatted_output(dump)).to eq '"\x04\b" l - "\b" "\x01\x00\x00\x00\x01\x00"'.b
      end
    end

    it 'returns tokens for dumped Float' do
      dump = "\x04\bf\t3.14"
      expect(Marshal.dump(3.14)).to eq dump

      expect(formatted_output(dump)).to eq '"\x04\b" f "\t" 3.14'.b
    end

    it 'returns tokens for dumped Rational' do
      dump = "\x04\bU:\rRational[\ai\x06i\a"
      expect(Marshal.dump(Rational(1, 2))).to eq dump

      expect(formatted_output(dump)).to eq '"\x04\b" U : "\r" Rational [ "\a" i "\x06" i "\a"'
    end

    it 'returns tokens for dumped Complex' do
      dump = "\x04\bU:\fComplex[\ai\x06i\a"
      expect(Marshal.dump(Complex(1, 2))).to eq dump

      expect(formatted_output(dump)).to eq '"\x04\b" U : "\f" Complex [ "\a" i "\x06" i "\a"'
    end

    it 'returns tokens for dumped String' do
      dump = "\x04\bI\"\nHello\x06:\x06ET"
      expect(Marshal.dump('Hello')).to eq dump

      expect(formatted_output(dump)).to eq '"\x04\b" I " "\n" Hello "\x06" : "\x06" E T'.b
    end

    it 'returns tokens for dumped Symbol' do
      dump = "\x04\b:\nHello"
      expect(Marshal.dump(:Hello)).to eq dump

      expect(formatted_output(dump)).to eq '"\x04\b" : "\n" Hello'.b
    end

    it 'returns tokens for dumped Symbol when there are duplicates' do
      dump = "\x04\b[\b:\nHello:\nworld;\x00"
      expect(Marshal.dump([:Hello, :world, :Hello])).to eq dump

      expect(formatted_output(dump)).to eq '"\x04\b" [ "\b" : "\n" Hello : "\n" world ; "\x00"'
    end

    it 'returns tokens for dumped Array' do
      dump = "\x04\b[\aTF"
      expect(Marshal.dump([true, false])).to eq dump

      expect(formatted_output(dump)).to eq '"\x04\b" [ "\a" T F'.b
    end

    describe 'Hash' do
      it 'returns tokens for dumped Hash' do
        dump = "\x04\b{\x06:\x06ai\x00"
        expect(Marshal.dump({a: 0})).to eq dump

        expect(formatted_output(dump)).to eq '"\x04\b" { "\x06" : "\x06" a i "\x00"'
      end

      it 'returns tokens for dumped Hash with default value' do
        dump = "\x04\b}\x00i/"

        hash = Hash.new(42)
        expect(Marshal.dump(hash)).to eq dump

        expect(formatted_output(dump)).to eq '"\x04\b" } "\x00" i /'.b
      end

      it 'returns tokens for dumped Hash with compare-by-identity behabiour' do
        dump = "\x04\bC:\tHash{\x00"

        hash = {}
        hash.compare_by_identity
        expect(Marshal.dump(hash)).to eq dump

        expect(formatted_output(dump)).to eq '"\x04\b" C : "\t" Hash { "\x00"'.b
      end
    end

    it 'returns tokens for dumped Range' do
      dump = "\x04\bo:\nRange\b:\texclF:\nbegini\x00:\bendi/"
      expect(Marshal.dump(0..42)).to eq dump

      expect(formatted_output(dump)).to eq '"\x04\b" o : "\n" Range "\b" : "\t" excl F : "\n" begin i "\x00" : "\b" end i /'.b
    end

    it 'returns tokens for dumped Regexp' do
      dump = "\x04\bI/\babc\x00\x06:\x06EF"
      expect(Marshal.dump(/abc/)).to eq dump

      expect(formatted_output(dump)).to eq '"\x04\b" I / "\b" abc "\x00" "\x06" : "\x06" E F'.b
    end

    describe 'Time' do
      it 'returns tokens for dumped Time' do
        dump = "\x04\bIu:\tTime\ri\xC7\x1E\x80\x00\x00\xE0\xCD\a:\voffseti\x020*:\tzone0".b

        time = Time.new(2023, 2, 27, 12, 51, 30, "+0300")
        expect(Marshal.dump(time)).to eq dump.b

        expect(formatted_output(dump)).to eq '"\x04\b" I u : "\t" Time "\r" "i\xC7\x1E\x80\x00\x00\xE0\xCD" "\a" : "\v" offset i "\x020*" : "\t" zone 0'.b
      end

      it 'returns tokens for dumped Time in UTC' do
        dump = "\x04\bIu:\tTime\rl\xC7\x1E\xC0,\x01\xE0\xCD\x06:\tzoneI\"\bUTC\x06:\x06EF".b

        time = Time.utc(2023, 2, 27, 12, 51, 30, "+0300")
        expect(Marshal.dump(time)).to eq dump.b

        expect(formatted_output(dump)).to eq '"\x04\b" I u : "\t" Time "\r" "l\xC7\x1E\xC0,\x01\xE0\xCD" "\x06" : "\t" zone I " "\b" UTC "\x06" : "\x06" E F'.b
      end
    end

    it 'returns tokens for dumped Class' do
      dump = "\x04\bc\vString"
      expect(Marshal.dump(String)).to eq dump

      expect(formatted_output(dump)).to eq '"\x04\b" c "\v" String'.b
    end

    it 'returns tokens for dumped Module' do
      dump = "\x04\bm\x0FEnumerable"
      expect(Marshal.dump(Enumerable)).to eq dump

      expect(formatted_output(dump)).to eq '"\x04\b" m "\x0F" Enumerable'.b
    end

    it 'returns tokens for dumped Struct' do
      dump = "\x04\bS:\fStructA\x06:\x06ai\x06"
      expect(Marshal.dump(StructA.new(1))).to eq dump

      expect(formatted_output(dump)).to eq '"\x04\b" S : "\f" StructA "\x06" : "\x06" a i "\x06"'.b
    end

    it 'returns tokens for dumped Encoding' do
      dump = "\x04\bIu:\rEncoding\nUTF-8\x06:\x06EF"
      expect(Marshal.dump(Encoding::UTF_8)).to eq dump

      expect(formatted_output(dump)).to eq '"\x04\b" I u : "\r" Encoding "\n" UTF-8 "\x06" : "\x06" E F'.b
    end

    it 'returns tokens for dumped BigDecimal' do
      dump = "\x04\bu:\x0FBigDecimal\x0F18:0.314e1"
      expect(Marshal.dump(BigDecimal('3.14'))).to eq dump

      expect(formatted_output(dump)).to eq '"\x04\b" u : "\x0F" BigDecimal "\x0F" 18:0.314e1'.b
    end

    describe 'subclass of Core Library classes' do
      it 'returns tokens for dumped subclass of Array' do
        dump = "\x04\bC:\x12ArraySubclass[\x00"
        expect(Marshal.dump(ArraySubclass.new)).to eq dump

        expect(formatted_output(dump)).to eq '"\x04\b" C : "\x12" ArraySubclass [ "\x00"'.b
      end

      it 'returns tokens for dumped subclass of String' do
        dump = "\x04\bC:\x13StringSubclass\"\x00"
        expect(Marshal.dump(StringSubclass.new)).to eq dump

        expect(formatted_output(dump)).to eq '"\x04\b" C : "\x13" StringSubclass " "\x00" '.b
      end

      it 'returns tokens for dumped subclass of Hash' do
        dump = "\x04\bC:\x11HashSubclass{\x00"
        expect(Marshal.dump(HashSubclass.new)).to eq dump

        expect(formatted_output(dump)).to eq '"\x04\b" C : "\x11" HashSubclass { "\x00"'.b
      end

      it 'returns tokens for dumped subclass of Regexp' do
        dump = "\x04\bIC:\x13RegexpSubclass/\babc\x00\x06:\x06EF"
        expect(Marshal.dump(RegexpSubclass.new('abc'))).to eq dump

        expect(formatted_output(dump)).to eq '"\x04\b" I C : "\x13" RegexpSubclass / "\b" abc "\x00" "\x06" : "\x06" E F'.b
      end
    end

    describe 'object' do
      it 'returns tokens for dumped object' do
        dump = "\x04\bo:\vObject\x00"
        expect(Marshal.dump(Object.new)).to eq dump

        expect(formatted_output(dump)).to eq '"\x04\b" o : "\v" Object "\x00"'.b
      end

      it 'returns tokens for dumped object with instance variables' do
        dump = "\x04\bo:\vObject\x06:\t@fooi\x00"

        object = Object.new
        object.instance_variable_set(:@foo, 0)
        expect(Marshal.dump(object)).to eq dump

        expect(formatted_output(dump)).to eq '"\x04\b" o : "\v" Object "\x06" : "\t" @foo i "\x00"'.b
      end

      it 'returns tokens for dumped object with #_dump method' do
        dump = "\x04\bIu:\x10UserDefined\b1:2\x06:\x06ET"
        expect(Marshal.dump(UserDefined.new(1, 2))).to eq dump

        expect(formatted_output(dump)).to eq '"\x04\b" I u : "\x10" UserDefined "\b" 1:2 "\x06" : "\x06" E T'.b
      end

      it 'returns tokens for dumped object with #marshal_dump method' do
        dump = "\x04\bU:\x10UserMarshal[\ai\x06i\a"
        expect(Marshal.dump(UserMarshal.new(1, 2))).to eq dump

        expect(formatted_output(dump)).to eq '"\x04\b" U : "\x10" UserMarshal [ "\a" i "\x06" i "\a"'.b
      end

      it 'returns tokens for dumped object extended with a module' do
        dump = "\x04\be:\x0FComparableo:\vObject\x00"

        object = Object.new
        object.extend(Comparable)
        expect(Marshal.dump(object)).to eq dump

        expect(formatted_output(dump)).to eq '"\x04\b" e : "\x0F" Comparable o : "\v" Object "\x00"'.b
      end
    end
  end
end

