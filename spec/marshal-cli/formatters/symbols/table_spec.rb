# frozen_string_literal: true

RSpec.describe MarshalParser::Formatters::Symbols::Table do
  describe "#string" do
    it "prints symbols as a table of # and a symbol" do
      symbols = %w[a b c]
      formatter = described_class.new(symbols)

      expect(formatter.string).to eq <<~'STR'.b.chomp
        0 - :a
        1 - :b
        2 - :c
      STR
    end

    it "adjust an indices column width to the largest index length" do
      symbols = (1..11).map(&:to_s)
      formatter = described_class.new(symbols)

      expect(formatter.string).to eq <<~'STR'.chomp
        0  - :1
        1  - :2
        2  - :3
        3  - :4
        4  - :5
        5  - :6
        6  - :7
        7  - :8
        8  - :9
        9  - :10
        10 - :11
      STR
    end
  end
end
