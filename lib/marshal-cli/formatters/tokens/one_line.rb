module MarshalParser
  module Formatters
    module Tokens
      class OneLine
        def initialize(tokens, source_string)
          @tokens = tokens
          @source_string = source_string
        end

        def string
          @tokens.map do |token|
            string = @source_string[token.index, token.length]
            string =~ /[^[:print:]]/ ? string.dump : string
          end.join(" ")
        end
      end
    end
  end
end
