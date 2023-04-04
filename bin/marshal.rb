require 'marshal-cli'
require 'dry/cli'

#dump = "\x04\b[\aI\"\nhello\x06:\x06ETI\"\nworld\x06;\x00T"
#lexer = MarshalCLI::Lexer.new(dump)
#lexer.run

#puts "Tokens:"
#formatter = MarshalCLI::TokensFormatter::OneLine.new(lexer.tokens, dump)
#puts formatter.string

#puts ""

#puts "Tokens with descriptions:"
#formatter = MarshalCLI::TokensFormatter::WithDescription.new(lexer.tokens, dump)
#puts formatter.string

# ruby -Ilib bin/marshal.rb ast --file array.dump --annotate --width=30 --symbols
# ruby -Ilib bin/marshal.rb ast -f array.dump -a -w 30 -s
# ruby -Ilib bin/marshal.rb ast -f array.dump -a -w 30 -s -c

module MarshalCLI
  module CLI
    module Commands
      extend Dry::CLI::Registry

      class Tokens < Dry::CLI::Command
        desc 'Parse a dump and print tokens'
        option :file,     type: :string,  aliases: ['-f'], desc: 'Read a dump from file with provided name'
        option :evaluate, type: :string,  aliases: ['-e'], desc: 'Ruby expression to dump'
        option :annotate, type: :boolean, aliases: ['-a'], desc: 'Print a table with annonated tokens'

        def call(**options)
          dump = \
            if options[:file]
              File.read(options[:file])
          elsif options[:evaluate]
            Marshal.dump(eval(options[:evaluate]))
          else
            STDIN.read
          end

          lexer = MarshalCLI::Lexer.new(dump)
          lexer.run

          if options[:annotate]
            formatter = MarshalCLI::Formatters::Tokens::WithDescription.new(lexer.tokens, dump)
          else
            formatter = MarshalCLI::Formatters::Tokens::OneLine.new(lexer.tokens, dump)
          end

          puts formatter.string
        end
      end

      class AST < Dry::CLI::Command
        desc 'Parse a dump and print AST'
        option :file,     type: :string,  aliases: ['-f'], desc: 'Read a dump from file with provided name'
        option :evaluate, type: :string,  aliases: ['-e'], desc: 'Ruby expression to dump'
        option :"only-tokens", type: :boolean, aliases: ['-o'], desc: 'Print only tokens'
        option :annotate, type: :boolean, aliases: ['-a'], desc: 'Print annotations'
        option :width,    type: :string,  aliases: ['-w'], desc: 'Width of the column with AST, used with --annotate'
        option :symbols,  type: :boolean, aliases: ['-s'], desc: 'Print a table of symbols'
        option :compact, type: :boolean, aliases: ['-c'], desc: "Don't print node attributes"

        def call(**options)
          dump = \
            if options[:file]
              File.read(options[:file])
          elsif options[:evaluate]
            Marshal.dump(eval(options[:evaluate]))
          else
            STDIN.read
          end

          lexer = Lexer.new(dump)
          lexer.run

          parser = Parser.new(lexer)
          ast = parser.parse

          renderer = \
            if options[:annotate]
              width = options[:width] ? Integer(options[:width]) : 50
              MarshalCLI::Formatters::AST::Renderers::RendererWithAnnotations.new(indent_size: 2, width: width)
            else
              MarshalCLI::Formatters::AST::Renderers::Renderer.new(indent_size: 2)
            end

          formatter = \
            if options[:"only-tokens"]
              MarshalCLI::Formatters::AST::OnlyTokens.new(ast, dump, renderer)
            elsif options[:compact]
              MarshalCLI::Formatters::AST::SExpressionCompact.new(ast, dump, renderer)
            else
              MarshalCLI::Formatters::AST::SExpression.new(ast, dump, renderer)
            end

          puts formatter.string

          if options[:symbols]
            symbols = parser.symbols
            puts ""
            puts "Symbols table:"
            puts MarshalCLI::Formatters::Symbols::Table.new(symbols).string
          end
        end
      end

      class Version < Dry::CLI::Command
        desc "Print version"

        def call(**)
          puts MarshalCLI::VERSION
        end
      end

      register 'tokens',  Tokens,   aliases: ['t']
      register 'ast',     AST,      aliases: ['a']
      register 'version', Version,  aliases: ['v', '-v', '--version']
    end
  end
end

Dry::CLI.new(MarshalCLI::CLI::Commands).call
