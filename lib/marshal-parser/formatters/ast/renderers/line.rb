# frozen_string_literal: true

module MarshalParser
  module Formatters
    module AST
      module Renderers
        class Line
          attr_reader :string

          def initialize(string)
            @string = string
          end
        end
      end
    end
  end
end
