module MarshalCLI
  module Formatters
    module AST
      class SExpressionCompact
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
          child_entries = node.child_entities
            .select { |e| e.is_a?(Parser::Node) || e == node.literal_token }
            .map do |e|
              if e.is_a?(Parser::Node)
                node_to_entries(e)
              else
                literal_token = node.literal_token
                value = node.attributes[literal_token][:value]

                if value.is_a?(Lexer::Token)
                  content = @source_string[value.index, value.length].dump
                else
                  content = value.to_s
                end

                Renderers::Line.new(content)
              end
            end
            .flatten

          name = node_to_name(node)
          entries = [Renderers::Line.new(name)] + child_entries

          if node.literal_token
            if entries.size == 2 && entries.all?(Renderers::Line)
              strings = entries.map(&:string)
              entries = [Renderers::Line.new(strings.join(' '))]
            end
          end

          unless node.always_leaf?
            entries[0] = Renderers::Line.new("(" + entries[0].string)
            close_bracket(entries.last)
          end

          raise "Expected 1st entry to be Line" unless entries[0].is_a?(Renderers::Line)

          if node.is_a?(Parser::Annotatable)
            string = entries[0].string
            annotation = node.annotation
            entries[0] = Renderers::LineAnnotated.new(string, annotation)
          end

          if entries.size > 1
            [entries[0], Renderers::EntriesBlock.new(entries[1..-1])]
          else
            entries
          end
        end

        # MarshalCLI::Parser::ObjectWithMarshalDumpMethod -> object-with-marshal-dump-method
        def node_to_name(node)
          node.class.name.to_s
            .split("::").last
            .sub(/Node\Z/, "")
            .gsub(/([a-z])([A-Z])/, '\1-\2')
            .downcase
        end

        def close_bracket(entry)
          case entry
          when Renderers::Line
            entry.string << ")"
          when Renderers::EntriesBlock
            close_bracket(entry.entries.last)
          end
        end

      end
    end
  end
end
