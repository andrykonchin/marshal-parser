# frozen_string_literal: true

module MarshalParser
  module Formatters
    module AST
      module Renderers
        class EntriesBlock
          attr_reader :entries

          def initialize(entries)
            @entries = entries
          end
        end
      end
    end
  end
end
