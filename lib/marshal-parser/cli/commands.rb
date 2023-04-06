# frozen_string_literal: true

require "dry/cli"

module MarshalParser
  module CLI
    module Commands
      extend Dry::CLI::Registry

      class Tokens < Dry::CLI::Command
        desc "Parse a dump and print tokens. By default reads dump from the stdin."
        option :file,     type: :string,  aliases: ["-f"], desc: "Read a dump from file with provided name"
        option :evaluate, type: :string,  aliases: ["-e"], desc: "Ruby expression to dump"
        option :annotate, type: :boolean, aliases: ["-a"], desc: "Print a table with annonated tokens"

        def call(**options)
          dump = \
            if options[:file]
              File.read(options[:file])
            elsif options[:evaluate]
              Marshal.dump(eval(options[:evaluate]))
            else
              $stdin.read
            end

          lexer = MarshalParser::Lexer.new(dump)
          lexer.run

          formatter = \
            if options[:annotate]
              MarshalParser::Formatters::Tokens::WithDescription.new(lexer.tokens, dump)
            else
              MarshalParser::Formatters::Tokens::OneLine.new(lexer.tokens, dump)
            end

          puts formatter.string
        end
      end

      class AST < Dry::CLI::Command
        desc "Parse a dump and print AST. By default reads dump from the stdin and uses S-expressions format."
        option :file,          type: :string,  aliases: ["-f"], desc: "Read a dump from file with provided name"
        option :evaluate,      type: :string,  aliases: ["-e"], desc: "Ruby expression to dump"
        option :"only-tokens", type: :boolean, aliases: ["-o"], desc: "Print only tokens"
        option :annotate,      type: :boolean, aliases: ["-a"], desc: "Print annotations"
        option :width,         type: :string,  aliases: ["-w"],
                               desc: "Width of the column with AST, used with --annotate"
        option :symbols,       type: :boolean, aliases: ["-s"], desc: "Print a table of symbols"
        option :compact,       type: :boolean, aliases: ["-c"], desc: "Don't print node attributes"

        def call(**options)
          dump = \
            if options[:file]
              File.read(options[:file])
            elsif options[:evaluate]
              Marshal.dump(eval(options[:evaluate]))
            else
              $stdin.read
            end

          lexer = Lexer.new(dump)
          lexer.run

          parser = Parser.new(lexer)
          ast = parser.parse

          renderer = \
            if options[:annotate]
              width = options[:width] ? Integer(options[:width]) : 50
              MarshalParser::Formatters::AST::Renderers::RendererWithAnnotations.new(indent_size: 2, width: width)
            else
              MarshalParser::Formatters::AST::Renderers::Renderer.new(indent_size: 2)
            end

          formatter = \
            if options[:"only-tokens"]
              MarshalParser::Formatters::AST::OnlyTokens.new(ast, dump, renderer)
            elsif options[:compact]
              MarshalParser::Formatters::AST::SExpressionCompact.new(ast, dump, renderer)
            else
              MarshalParser::Formatters::AST::SExpression.new(ast, dump, renderer)
            end

          puts formatter.string

          if options[:symbols]
            symbols = parser.symbols
            puts ""
            puts "Symbols table:"
            puts MarshalParser::Formatters::Symbols::Table.new(symbols).string
          end
        end
      end

      class Version < Dry::CLI::Command
        desc "Print version"

        def call(**)
          puts MarshalParser::VERSION
        end
      end

      register "tokens",  Tokens,   aliases: ["t"]
      register "ast",     AST,      aliases: ["a"]
      register "version", Version,  aliases: ["v", "-v", "--version"]
    end
  end
end
