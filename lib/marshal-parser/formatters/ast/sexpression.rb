# frozen_string_literal: true

module MarshalParser
  module Formatters
    module AST
      class SExpression
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
            .select { |e| (e.is_a?(Lexer::Token) && node.attributes.key?(e)) || e.is_a?(Parser::Node) }
            .map do |entry|
              case entry
              when Lexer::Token
                options = node.attributes[entry]
                name = options[:name]
                value = options[:value]

                name = name.to_s.gsub(/_/, "-")

                if value.is_a?(Lexer::Token)
                  value = @source_string[entry.index, entry.length].dump
                end

                Renderers::Line.new("(#{name} #{value})")
              when Parser::Node
                node_to_entries(entry)
              end
            end.flatten

          name = node_to_name(node)
          entries = [Renderers::Line.new("(#{name}")] + child_entries
          close_bracket(entries.last)

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

        # MarshalParser::Parser::ObjectWithMarshalDumpMethod -> object-with-marshal-dump-method
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
