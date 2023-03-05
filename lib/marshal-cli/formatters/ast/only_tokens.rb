module MarshalCLI
  module Formatters
    module AST
      class OnlyTokens
        def initialize(node, source_string, renderer)
          @node = node
          @source_string = source_string
          @renderer = renderer
        end

        def string
          entries = node_to_entries(@node)
          block = EntriesBlock.new(entries)
          @renderer.render(block)
        end

        private

        def node_to_entries(node)
          entries = node.child_entities.map do |child|
            case child
            when Lexer::Token
              string = @source_string[child.index, child.length]
              string = string.dump if string =~ /[^[:print:]]/ # TODO: How to detect \n, \r etc that may break formatting?

              Line.new(string)
            when Parser::Node
              node_to_entries(child)
            else
              raise "Unexpected node child entity #{child}"
            end
          end.flatten

          # short oneline form, e.g. for Symbol - (: "\x06" E)
          if node.children.empty?
            # ignore "" as the last token and strip inserted whitespace
            string = entries.map(&:string).join(" ").strip
            entries = [Line.new(string)]
          end

          raise "Expected 1st entry to be Line" unless entries[0].is_a?(Line)

          if node.is_a?(Parser::Annotatable)
            string = entries[0].string
            annotation = node.annotation
            entries[0] = LineAnnotated.new(string, annotation)
          end

          if entries.size > 1
            [entries[0], EntriesBlock.new(entries[1..-1])]
          else
            entries
          end
        end

        class Line
          attr_reader :string

          def initialize(string)
            @string = string
          end
        end

        class LineAnnotated < Line
          attr_reader :annotation

          def initialize(string, annotation)
            super(string)
            @annotation = annotation
          end
        end

        class EntriesBlock
          attr_reader :entries

          def initialize(entries)
            @entries = entries
          end
        end

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
              end
            end.flatten
          end
        end

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
