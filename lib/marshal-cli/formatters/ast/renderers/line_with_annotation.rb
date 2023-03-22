module MarshalCLI
  module Formatters
    module AST
      module Renderers
        class LineAnnotated < Line
          attr_reader :annotation

          def initialize(string, annotation)
            super(string)
            @annotation = annotation
          end
        end
      end
    end
  end
end