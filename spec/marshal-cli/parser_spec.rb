# frozen_string_literal: true

RSpec.describe MarshalCLI::Parser do
  describe '#parse' do
    Parser = described_class

    def string_to_ast(string)
      lexer = MarshalCLI::Lexer.new(string)
      lexer.run
      parser = MarshalCLI::Parser.new(lexer)
      parser.parse
    end

    it 'returns AST for dumped true' do
      dump = "\x04\bT"
      expect(Marshal.dump(true)).to eq dump

      expect(string_to_ast(dump)).to be_like_ast(Parser::TrueNode)
    end

    it 'returns AST for dumped false' do
      dump = "\x04\bF"
      expect(Marshal.dump(false)).to eq dump

      expect(string_to_ast(dump)).to be_like_ast(Parser::FalseNode)
    end

    it 'returns AST for dumped nil' do
      dump = "\x04\b0"
      expect(Marshal.dump(nil)).to eq dump

      expect(string_to_ast(dump)).to be_like_ast(Parser::NilNode)
    end

    describe 'Integer' do
      it 'returns AST for dumped 0' do
        dump = "\x04\bi\x00".b
        expect(Marshal.dump(0)).to eq dump

        expect(string_to_ast(dump)).to be_like_ast(Parser::IntegerNode => encoded_value(0))
      end

      it 'returns AST for dumped 5..122 (a sign-extended eight-bit value with an offset)' do
        dump = "\x04\bi\x7F".b
        expect(Marshal.dump(122)).to eq dump

        expect(string_to_ast(dump)).to be_like_ast(Parser::IntegerNode => encoded_value(122))
      end

      it 'returns AST for dumped -122..-5 (a sign-extended eight-bit value with an offset)' do
        dump = "\x04\bi\x81".b
        expect(Marshal.dump(-122)).to eq dump

        expect(string_to_ast(dump)).to be_like_ast(Parser::IntegerNode => encoded_value(-122))
      end

      it 'returns AST for dumped 123..255 (0x01 + the following byte is a positive integer)' do
        dump = "\x04\bi\x01\xFF".b
        expect(Marshal.dump(255)).to eq dump

        expect(string_to_ast(dump)).to be_like_ast(Parser::IntegerNode => encoded_value(255))
      end

      it 'returns AST for dumped -256..-124 (0xFF + the following byte is a negative integer)' do
        dump = "\x04\bi\xFF\x01".b
        expect(Marshal.dump(-255)).to eq dump

        expect(string_to_ast(dump)).to be_like_ast(Parser::IntegerNode => encoded_value(-255))
      end

      it 'returns AST for dumped XX XX (0x02 + the following 2 bytes is a positive little-endian integer)' do
        dump = "\x04\bi\x024\x12".b
        expect(Marshal.dump(0x1234)).to eq dump

        expect(string_to_ast(dump)).to be_like_ast(Parser::IntegerNode => encoded_value(0x1234))
      end

      it 'returns AST for dumped -XX XX (0xFE + the following 2 bytes is a negative little-endian integer)' do
        dump = "\x04\bi\xFE\xCC\xED".b
        expect(Marshal.dump(-0x1234)).to eq dump

        expect(string_to_ast(dump)).to be_like_ast(Parser::IntegerNode => encoded_value(-0x1234))
      end

      it 'returns AST for dumped XX XX XX (0x03 + the following 3 bytes is a positive little-endian integer)' do
        dump = "\x04\bi\x03V4\x12".b
        expect(Marshal.dump(0x123456)).to eq dump

        expect(string_to_ast(dump)).to be_like_ast(Parser::IntegerNode => encoded_value(0x123456))
      end

      it 'returns AST for dumped -XX XX XX (0xFD + the following 3 bytes is a negative little-endian integer)' do
        dump = "\x04\bi\xFD\xAA\xCB\xED".b
        expect(Marshal.dump(-0x123456)).to eq dump

        expect(string_to_ast(dump)).to be_like_ast(Parser::IntegerNode => encoded_value(-0x123456))
      end

      it 'returns AST for dumped XX XX XX XX (0x04 + the following 4 bytes is a positive little-endian integer)' do
        dump = "\x04\bi\x04xV4\x12".b
        expect(Marshal.dump(0x12345678)).to eq dump

        expect(string_to_ast(dump)).to be_like_ast(Parser::IntegerNode => encoded_value(0x12345678))
      end

      it 'returns AST for dumped -XX XX XX XX (0xFC + the following 4 bytes is a negative little-endian integer)' do
        dump = "\x04\bi\xFC\x88\xA9\xCB\xED".b
        expect(Marshal.dump(-0x12345678)).to eq dump

        expect(string_to_ast(dump)).to be_like_ast(Parser::IntegerNode => encoded_value(-0x12345678))
      end

      it 'returns AST for dumped positive big Integer (Bignum, > 2^32)' do
        dump = "\x04\bl+\b\x01\x00\x00\x00\x01\x00".b
        expect(Marshal.dump(2.pow(32) + 1)).to eq dump

        expect(string_to_ast(dump)).to be_like_ast(Parser::BigIntegerNode => encoded_value(2.pow(32) + 1))
      end

      it 'returns AST for dumped negative big Integer (Bignum)' do
        dump = "\x04\bl-\b\x01\x00\x00\x00\x01\x00".b
        expect(Marshal.dump(-(2.pow(32)) - 1)).to eq dump

        expect(string_to_ast(dump)).to be_like_ast(Parser::BigIntegerNode => encoded_value(-(2.pow(32)) - 1))
      end
    end

    it 'returns AST for dumped Float' do
      dump = "\x04\bf\t3.14"
      expect(Marshal.dump(3.14)).to eq dump

      expect(string_to_ast(dump)).to be_like_ast(Parser::FloatNode => encoded_value(3.14))
    end

    it 'returns AST for dumped Rational' do
      dump = "\x04\bU:\rRational[\ai\x06i\a"
      expect(Marshal.dump(Rational(1, 2))).to eq dump

      expect(string_to_ast(dump)).to be_like_ast(
        Parser::ObjectWithMarshalDump => children_nodes(
          { Parser::SymbolNode => literal_value('Rational', dump) },
          Parser::ArrayNode => children_nodes(
            { Parser::IntegerNode => encoded_value(1) },
            { Parser::IntegerNode => encoded_value(2) }
          )
        )
      )
    end

    it 'returns AST for dumped Complex' do
      dump = "\x04\bU:\fComplex[\ai\x06i\a"
      expect(Marshal.dump(Complex(1, 2))).to eq dump

      expect(string_to_ast(dump)).to be_like_ast(
        Parser::ObjectWithMarshalDump => children_nodes(
          { Parser::SymbolNode => literal_value('Complex', dump) },
          Parser::ArrayNode => children_nodes(
            { Parser::IntegerNode => encoded_value(1) },
            { Parser::IntegerNode => encoded_value(2) }
          )
        )
      )
    end

    it 'returns AST for dumped String' do
      dump = "\x04\bI\"\nHello\x06:\x06ET"
      expect(Marshal.dump('Hello')).to eq dump

      expect(string_to_ast(dump)).to be_like_ast(
        Parser::ObjectWithIVarsNode => children_nodes(
          { Parser::StringNode => literal_value('Hello', dump) },
          { Parser::SymbolNode => literal_value('E', dump) },
          Parser::TrueNode
        ))
    end

    it 'returns AST for dumped Symbol' do
      dump = "\x04\b:\nHello"
      expect(Marshal.dump(:Hello)).to eq dump

      expect(string_to_ast(dump)).to be_like_ast(
        Parser::SymbolNode => literal_value('Hello', dump))
    end

    it 'returns AST for dumped Symbol when there are duplicates' do
      dump = "\x04\b[\b:\nHello:\nworld;\x00"
      expect(Marshal.dump([:Hello, :world, :Hello])).to eq dump

      expect(string_to_ast(dump)).to be_like_ast(
        Parser::ArrayNode => children_nodes(
          { Parser::SymbolNode => literal_value('Hello', dump) },
          { Parser::SymbolNode => literal_value('world', dump) },
          { Parser::SymbolLinkNode => encoded_value(0) },
        ))
    end

    it 'returns AST for dumped Array' do
      dump = "\x04\b[\aTF"
      expect(Marshal.dump([true, false])).to eq dump

      expect(string_to_ast(dump)).to be_like_ast(
        Parser::ArrayNode => children_nodes(
          Parser::TrueNode,
          Parser::FalseNode
        ))
    end

    describe 'Hash' do
      it 'returns AST for dumped Hash' do
        dump = "\x04\b{\x06:\x06ai\x00"
        expect(Marshal.dump({a: 0})).to eq dump

        expect(string_to_ast(dump)).to be_like_ast(
          Parser::HashNode => children_nodes(
            { Parser::SymbolNode => literal_value('a', dump) },
            { Parser::IntegerNode => encoded_value(0) }
          ))
      end

      it 'returns AST for dumped Hash with default value' do
        dump = "\x04\b}\x00i/"

        hash = Hash.new(42)
        expect(Marshal.dump(hash)).to eq dump

        expect(string_to_ast(dump)).to be_like_ast(
          Parser::HashWithDefaultValueNode => children_nodes(
            { Parser::IntegerNode => encoded_value(42) }
          ))
      end

      it 'returns AST for dumped Hash with compare-by-identity behabiour' do
        dump = "\x04\bC:\tHash{\x00"

        hash = {}
        hash.compare_by_identity
        expect(Marshal.dump(hash)).to eq dump

        expect(string_to_ast(dump)).to be_like_ast(
          Parser::SubclassNode => children_nodes(
            { Parser::SymbolNode => literal_value('Hash', dump) },
            { Parser::HashNode => children_nodes() },
          ),
        )
      end
    end

    it 'returns AST for dumped Range' do
      dump = "\x04\bo:\nRange\b:\texclF:\nbegini\x00:\bendi/"
      expect(Marshal.dump(0..42)).to eq dump

      expect(string_to_ast(dump)).to be_like_ast(
        Parser::ObjectNode => children_nodes(
          { Parser::SymbolNode => literal_value('Range', dump) },
          { Parser::SymbolNode => literal_value('excl', dump) },
          Parser::FalseNode,
          { Parser::SymbolNode => literal_value('begin', dump) },
          { Parser::IntegerNode => encoded_value(0) },
          { Parser::SymbolNode => literal_value('end', dump) },
          { Parser::IntegerNode => encoded_value(42) }
        )
      )
    end

    it 'returns AST for dumped Regexp' do
      dump = "\x04\bI/\babc\x00\x06:\x06EF"
      expect(Marshal.dump(/abc/)).to eq dump

      expect(string_to_ast(dump)).to be_like_ast(
        Parser::ObjectWithIVarsNode => children_nodes(
          { Parser::RegexpNode => literal_value('abc', dump) },
          { Parser::SymbolNode => literal_value('E', dump) },
          Parser::FalseNode
        )
      )
    end

    describe 'Time' do
      it 'returns AST for dumped Time' do
        dump = "\x04\bIu:\tTime\ri\xC7\x1E\x80\x00\x00\xE0\xCD\a:\voffseti\x020*:\tzone0"

        time = Time.new(2023, 2, 27, 12, 51, 30, "+0300")
        expect(Marshal.dump(time)).to eq dump.b

        expect(string_to_ast(dump)).to be_like_ast(
          Parser::ObjectWithIVarsNode => children_nodes(
            {
              Parser::ObjectWithDumpNode => [
                children_nodes(
                  Parser::SymbolNode => literal_value('Time', dump)),
                literal_value("i\xC7\x1E\x80\x00\x00\xE0\xCD", dump),
              ]
            },
            { Parser::SymbolNode => literal_value('offset', dump) },
            { Parser::IntegerNode => encoded_value(10800) },

            { Parser::SymbolNode => literal_value('zone', dump) },
            Parser::NilNode,
          )
        )
      end

      it 'returns AST for dumped Time in UTC' do
        dump = "\x04\bIu:\tTime\rl\xC7\x1E\xC0,\x01\xE0\xCD\x06:\tzoneI\"\bUTC\x06:\x06EF"

        time = Time.utc(2023, 2, 27, 12, 51, 30, '+0300')
        expect(Marshal.dump(time)).to eq dump.b

        expect(string_to_ast(dump)).to be_like_ast(
          Parser::ObjectWithIVarsNode => children_nodes(
            {
              Parser::ObjectWithDumpNode => [
                children_nodes(
                  Parser::SymbolNode => literal_value('Time', dump)),
                literal_value("l\xC7\x1E\xC0,\x01\xE0\xCD", dump),
              ]
            },
            { Parser::SymbolNode => literal_value('zone', dump) },
            Parser::ObjectWithIVarsNode => children_nodes(
              { Parser::StringNode => literal_value('UTC', dump) },
              { Parser::SymbolNode => literal_value('E', dump) },
              Parser::FalseNode,
            )
          )
        )
      end
    end

    it 'returns AST for dumped Class' do
      dump = "\x04\bc\vString"
      expect(Marshal.dump(String)).to eq dump

      expect(string_to_ast(dump)).to be_like_ast(
        Parser::ClassNode => literal_value('String', dump))
    end

    it 'returns AST for dumped Module' do
      dump = "\x04\bm\x0FEnumerable"
      expect(Marshal.dump(Enumerable)).to eq dump

      expect(string_to_ast(dump)).to be_like_ast(
        Parser::ModuleNode => literal_value('Enumerable', dump))
    end

    it 'returns AST for dumped Struct' do
      dump = "\x04\bS:\fStructA\x06:\x06ai\x06"
      expect(Marshal.dump(StructA.new(1))).to eq dump

      expect(string_to_ast(dump)).to be_like_ast(
        Parser::StructNode => children_nodes(
          { Parser::SymbolNode => literal_value('StructA', dump) },
          { Parser::SymbolNode => literal_value('a', dump) },
          Parser::IntegerNode => encoded_value(1),
        )
      )
    end

    it 'returns AST for dumped Encoding' do
      dump = "\x04\bIu:\rEncoding\nUTF-8\x06:\x06EF"
      expect(Marshal.dump(Encoding::UTF_8)).to eq dump

      expect(string_to_ast(dump)).to be_like_ast(
        Parser::ObjectWithIVarsNode => children_nodes(
          {
            Parser::ObjectWithDumpNode => [
              children_nodes(
                Parser::SymbolNode => literal_value('Encoding', dump)),
              literal_value('UTF-8', dump)
            ],
          },
          { Parser::SymbolNode => literal_value('E', dump) },
          Parser::FalseNode,
        )
      )
    end

    require 'bigdecimal'

    it 'returns AST for dumped BigDecimal' do
      dump = "\x04\bu:\x0FBigDecimal\x0F18:0.314e1"
      expect(Marshal.dump(BigDecimal('3.14'))).to eq dump

      expect(string_to_ast(dump)).to be_like_ast(
        Parser::ObjectWithDumpNode => [
          children_nodes(
            Parser::SymbolNode => literal_value('BigDecimal', dump)),
          literal_value('18:0.314e1', dump)
        ]
      )
    end

    describe 'subclass of Core Library classes' do
      it 'returns AST for dumped subclass of Array' do
        dump = "\x04\bC:\x12ArraySubclass[\x00"
        expect(Marshal.dump(ArraySubclass.new)).to eq dump

        expect(string_to_ast(dump)).to be_like_ast(
          Parser::SubclassNode => children_nodes(
            { Parser::SymbolNode => literal_value('ArraySubclass', dump) },
            { Parser::ArrayNode => children_nodes() },
          )
        )
      end

      it 'returns AST for dumped subclass of String' do
        dump = "\x04\bC:\x13StringSubclass\"\x00"
        expect(Marshal.dump(StringSubclass.new)).to eq dump

        expect(string_to_ast(dump)).to be_like_ast(
          Parser::SubclassNode => children_nodes(
            { Parser::SymbolNode => literal_value('StringSubclass', dump) },
            { Parser::StringNode => literal_value('', dump) },
          )
        )
      end

      it 'returns AST for dumped subclass of Hash' do
        dump = "\x04\bC:\x11HashSubclass{\x00"
        expect(Marshal.dump(HashSubclass.new)).to eq dump

        expect(string_to_ast(dump)).to be_like_ast(
          Parser::SubclassNode => children_nodes(
            { Parser::SymbolNode => literal_value('HashSubclass', dump) },
            { Parser::HashNode => children_nodes() },
          )
        )
      end

      it 'returns AST for dumped subclass of Regexp' do
        dump = "\x04\bIC:\x13RegexpSubclass/\babc\x00\x06:\x06EF"
        expect(Marshal.dump(RegexpSubclass.new('abc'))).to eq dump

        expect(string_to_ast(dump)).to be_like_ast(
          Parser::ObjectWithIVarsNode => children_nodes(
            {
              Parser::SubclassNode => children_nodes(
                { Parser::SymbolNode => literal_value('RegexpSubclass', dump) },
                { Parser::RegexpNode => literal_value('abc', dump) },
              ),
            },
            { Parser::SymbolNode => literal_value('E', dump) },
            Parser::FalseNode,
          )
        )
      end
    end

    describe 'object' do
      it 'returns AST for dumped object' do
        dump = "\x04\bo:\vObject\x00"
        expect(Marshal.dump(Object.new)).to eq dump

        expect(string_to_ast(dump)).to be_like_ast(
          Parser::ObjectNode => children_nodes(
            Parser::SymbolNode => literal_value('Object', dump)
          ))
      end

      it 'returns AST for dumped object with instance variables' do
        dump = "\x04\bo:\vObject\x06:\t@fooi\x00"

        object = Object.new
        object.instance_variable_set(:@foo, 0)
        expect(Marshal.dump(object)).to eq dump

        expect(string_to_ast(dump)).to be_like_ast(
          Parser::ObjectNode => children_nodes(
            { Parser::SymbolNode => literal_value('Object', dump) },
            { Parser::SymbolNode => literal_value('@foo', dump) },
            { Parser::IntegerNode => encoded_value(0) }
          )
        )
      end

      it 'returns AST for dumped object with duplicates' do
        dump = "\x04\b[\bo:\vObject\x00T@\x06"
        object = Object.new
        expect(Marshal.dump([object, true, object])).to eq dump

        expect(string_to_ast(dump)).to be_like_ast(
          Parser::ArrayNode => children_nodes(
            {
              Parser::ObjectNode => children_nodes(
                { Parser::SymbolNode => literal_value('Object', dump) })
            },
            Parser::TrueNode,
            Parser::ObjectLinkNode => encoded_value(1)
          )
        )
      end

      it 'returns AST for dumped object with #_dump method' do
        dump = "\x04\bIu:\x10UserDefined\b1:2\x06:\x06ET"
        expect(Marshal.dump(UserDefined.new(1, 2))).to eq dump

        expect(string_to_ast(dump)).to be_like_ast(
          Parser::ObjectWithIVarsNode => children_nodes(
            {
              Parser::ObjectWithDumpNode => children_nodes(
                Parser::SymbolNode => literal_value('UserDefined', dump)
              )
            },
            { Parser::SymbolNode => literal_value('E', dump) },
            Parser::TrueNode
          ))
      end

      it 'returns AST for dumped object with #marshal_dump method' do
        dump = "\x04\bU:\x10UserMarshal[\ai\x06i\a"
        expect(Marshal.dump(UserMarshal.new(1, 2))).to eq dump

        expect(string_to_ast(dump)).to be_like_ast(
          Parser::ObjectWithMarshalDump => children_nodes(
            { Parser::SymbolNode => literal_value('UserMarshal', dump) },
            Parser::ArrayNode => children_nodes(
              { Parser::IntegerNode => encoded_value(1) },
              { Parser::IntegerNode => encoded_value(2) }
            )
          )
        )
      end

      it 'returns AST for dumped object extended with a module' do
        dump = "\x04\be:\x0FComparableo:\vObject\x00"

        object = Object.new
        object.extend(Comparable)
        expect(Marshal.dump(object)).to eq dump

        expect(string_to_ast(dump)).to be_like_ast(
          Parser::ObjectExtendedNode => children_nodes(
            { Parser::SymbolNode => literal_value('Comparable', dump) },
            {
              Parser::ObjectNode => children_nodes(
                Parser::SymbolNode => literal_value('Object', dump))
            }
          )
        )
      end
    end
  end
end
