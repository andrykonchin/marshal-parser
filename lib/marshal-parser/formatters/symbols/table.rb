# frozen_string_literal: true

module MarshalParser
  module Formatters
    module Symbols
      class Table
        def initialize(symbols)
          @symbols = symbols
        end

        def string
          width = digits_in(@symbols.size)

          @symbols.map.with_index do |symbol, i|
            "%-#{width}d - :%s" % [i, symbol]
          end.join("\n")
        end

        private def digits_in(n)
          i = 0

          while n > 0
            i += 1
            n /= 10
          end

          i
        end
      end
    end
  end
end
