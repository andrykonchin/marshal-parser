module MarshalParser
  module Formatters
    module AST
      module Renderers
        class Renderer
          def initialize(indent_size:)
            @indent_size = indent_size
          end

          def render(block)
            lines = apply_indentation(block, 0)
            strings = lines.map(&:string)
            strings.join("\n")
          end

          private

          def apply_indentation(block, level)
            indentation = " " * @indent_size * level

            block.entries.map do |e|
              case e
              when Line
                Line.new(indentation + e.string)
              when EntriesBlock
                apply_indentation(e.entries, level + 1)
              else
                raise "Unexpected entry #{e} (#{e.class}), expected Line or EntriesBlock"
              end
            end.flatten
          end
        end
      end
    end
  end
end
