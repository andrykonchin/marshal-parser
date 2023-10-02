# frozen_string_literal: true

module MarshalParser
  module Formatters
    module Tokens
      class OneLine
        def initialize(tokens, source_string, hex: nil)
          @tokens = tokens
          @source_string = source_string
          @hex = hex
        end

        def string
          unless @hex
            @tokens.map do |token|
              string = @source_string[token.index, token.length]
              string =~ /[^[:print:]]/ ? string.dump : string
            end.join(" ")
          else
            @tokens.map do |token|
              string = @source_string[token.index, token.length]
              string = string.bytes.map { |b| "%02X" % b }.join(" ")
            end.join("  ")
          end
        end
      end
    end
  end
end
