# frozen_string_literal: true

RSpec.describe MarshalCLI::Lexer do
  describe '#tokens' do
    Lexer = described_class

    def string_to_tokens(string)
      lexer = described_class.new(string)
      lexer.run
      lexer.tokens
    end

    it 'returns tokens for dumped true' do
      dump = "\x04\bT"
      expect(Marshal.dump(true)).to eq dump

      expect(string_to_tokens(dump)).to eq [
        Lexer::Token.new(Lexer::VERSION, 0, 2, '4.8'),
        Lexer::Token.new(Lexer::TRUE, 2, 1, true)
      ]
    end

    it 'returns tokens for dumped false' do
      dump = "\x04\bF"
      expect(Marshal.dump(false)).to eq dump

      expect(string_to_tokens(dump)).to eq [
        Lexer::Token.new(Lexer::VERSION, 0, 2, '4.8'),
        Lexer::Token.new(Lexer::FALSE, 2, 1, false)
      ]
    end

    #it 'returns tokens for dumped nil'

    #it 'returns tokens for dumped Integer' # different formats
    #it 'returns tokens for dumped Float'
    #it 'returns tokens for dumped Rational'
    #it 'returns tokens for dumped Complex'

    it 'returns tokens for dumped String' do
      dump = "\x04\bI\"\nHello\x06:\x06ET"
      expect(Marshal.dump('Hello')).to eq dump

      expect(string_to_tokens(dump)).to eq [
        Lexer::Token.new(Lexer::VERSION, 0, 2, '4.8'),
        Lexer::Token.new(Lexer::OBJECT_WITH_IVARS_PREFIX, 2, 1),
        Lexer::Token.new(Lexer::STRING_PREFIX, 3, 1),
        Lexer::Token.new(Lexer::INTEGER, 4, 1, 5),
        Lexer::Token.new(Lexer::STRING, 5, 5, 'Hello'),
        Lexer::Token.new(Lexer::INTEGER, 10, 1, 1),
        Lexer::Token.new(Lexer::SYMBOL_PREFIX, 11, 1),
        Lexer::Token.new(Lexer::INTEGER, 12, 1, 1),
        Lexer::Token.new(Lexer::SYMBOL, 13, 1, 'E'),
        Lexer::Token.new(Lexer::TRUE, 14, 1, true)
      ]
    end

    it 'returns tokens for dumped Symbol' do
      dump = "\x04\b:\nHello"
      expect(Marshal.dump(:Hello)).to eq dump

      expect(string_to_tokens(dump)).to eq [
        Lexer::Token.new(Lexer::VERSION, 0, 2, '4.8'),
        Lexer::Token.new(Lexer::SYMBOL_PREFIX, 2, 1),
        Lexer::Token.new(Lexer::INTEGER, 3, 1, 5),
        Lexer::Token.new(Lexer::SYMBOL, 4, 5, 'Hello')
      ]
    end

    it 'returns tokens for dumped Array' do
      dump = "\x04\b[\aTF"
      expect(Marshal.dump([true, false])).to eq dump

      expect(string_to_tokens(dump)).to eq [
        Lexer::Token.new(Lexer::VERSION, 0, 2, '4.8'),
        Lexer::Token.new(Lexer::ARRAY_PREFIX, 2, 1),
        Lexer::Token.new(Lexer::INTEGER, 3, 1, 2),
        Lexer::Token.new(Lexer::TRUE, 4, 1, true),
        Lexer::Token.new(Lexer::FALSE, 5, 1, false)
      ]
    end

    #it 'returns tokens for dumped Hash' # different formats
    #it 'returns tokens for dumped Range'
    #it 'returns tokens for dumped Regexp'
    #it 'returns tokens for dumped Time'
    #it 'returns tokens for dumped Class'
    #it 'returns tokens for dumped Module'
    #it 'returns tokens for dumped Struct'
    #it 'returns tokens for dumped Encoding'
    #it 'returns tokens for dumped BigDecimal'
    #it 'returns tokens for dumped subclass of Array'
    #it 'returns tokens for dumped subclass of Hash'
    #it 'returns tokens for dumped subclass of Regexp'
    #it 'returns tokens for dumped subclass of String'
    #it 'returns tokens for dumped subclass of Array'

    #it 'returns tokens for dumped object'
    #it 'returns tokens for dumped object with #_dump method'
    #it 'returns tokens for dumped object with #marshal_dump method'
    #it 'returns tokens for dumped object extended with a module'
    #it 'returns tokens for dumped object extended with a module'

  end
end
