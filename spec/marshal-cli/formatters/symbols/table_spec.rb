# frozen_string_literal: true

RSpec.describe MarshalParser::Formatters::Symbols::Table do
  describe "#string" do
    it "prints symbols as a table of # and a symbol" do
      symbols = %w[a b c]
      formatter = described_class.new(symbols)

      expect(formatter.string).to eq <<~'STR'.b.chomp
        0    - :a
        1    - :b
        2    - :c
      STR
    end
  end
end
