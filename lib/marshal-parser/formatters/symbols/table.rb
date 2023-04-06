# frozen_string_literal: true

module MarshalParser
  module Formatters
    module Symbols
      class Table
        def initialize(symbols)
          @symbols = symbols
        end

        def string
          @symbols.map.with_index do |symbol, i|
            "%-4d - :%s" % [i, symbol]
          end.join("\n")
        end
      end
    end
  end
end
