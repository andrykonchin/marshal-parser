module MarshalCLI
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
          block = EntriesBlock.new(entries)
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

                Line.new("(#{name} #{value})")
              when Parser::Node
                node_to_entries(entry)
              end
            end.flatten

          title = node.class.name.to_s.split("::").last.sub(/Node\Z/, "").gsub(/([a-z])([A-Z])/, '\1-\2').downcase
          entries = [Line.new("(" + title)] + child_entries
          close_bracket(entries.last)

          raise "Expected 1st entry to be Line" unless entries[0].is_a?(Renderers::Line)

          if node.is_a?(Parser::Annotatable)
            string = entries[0].string
            annotation = node.annotation
            entries[0] = Renderers::LineAnnotated.new(string, annotation)
          end

          if entries.size > 1
            [entries[0], EntriesBlock.new(entries[1..-1])]
          else
            entries
          end
        end

        def close_bracket(entry)
          case entry
          when Line
            entry.string << ")"
          when EntriesBlock
            close_bracket(entry.entries.last)
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
              else
                raise "Unexpected entry #{e} (#{e.class}), expected Line or EntriesBlock"
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
