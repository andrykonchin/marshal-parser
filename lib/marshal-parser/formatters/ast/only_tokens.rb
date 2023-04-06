# frozen_string_literal: true

module MarshalParser
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
          block = Renderers::EntriesBlock.new(entries)
          @renderer.render(block)
        end

        private

        def node_to_entries(node)
          entries = node.child_entities.map do |child|
            case child
            when Lexer::Token
              string = @source_string[child.index, child.length]
              string = string.dump if string =~ /[^[:print:]]/ # TODO: How to detect \n, \r etc that may break formatting?

              Renderers::Line.new(string)
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
            entries = [Renderers::Line.new(string)]
          end

          raise "Expected 1st entry to be Line" unless entries[0].is_a?(Renderers::Line)

          if node.is_a?(Parser::Annotatable)
            string = entries[0].string
            annotation = node.annotation
            entries[0] = Renderers::LineAnnotated.new(string, annotation)
          end

          if entries.size > 1
            [entries[0], Renderers::EntriesBlock.new(entries[1..])]
          else
            entries
          end
        end
      end
    end
  end
end
