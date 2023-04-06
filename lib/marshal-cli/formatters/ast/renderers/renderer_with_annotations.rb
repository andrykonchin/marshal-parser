module MarshalParser
  module Formatters
    module AST
      module Renderers
        class RendererWithAnnotations
          def initialize(indent_size:, width:)
            @indent_size = indent_size
            @width = width
          end

          def render(block)
            # indent
            lines = apply_indentation(block, 0)

            # add annotations
            strings = lines.map do |line|
              case line
              when LineAnnotated
                "%-#{@width}s # %s" % [line.string, line.annotation]
              when Line
                line.string
              else
                raise "Unexpected line #{e} (#{e.class}), expected Line or LineAnnotated"
              end
            end

            strings.join("\n")
          end

          private

          def apply_indentation(block, level)
            indentation = " " * @indent_size * level

            block.entries.map do |e|
              case e
              when LineAnnotated
                LineAnnotated.new(indentation + e.string, e.annotation)
              when Line
                Line.new(indentation + e.string)
              when EntriesBlock
                apply_indentation(e.entries, level + 1)
              end
            end.flatten
          end
        end
      end
    end
  end
end
