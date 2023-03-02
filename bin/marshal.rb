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

module MarshalCLI
  module CLI
    module Commands
      extend Dry::CLI::Registry

      class Tokens < Dry::CLI::Command
        desc 'Parse a dump and print tokens'
        option :file,     type: :string,  aliases: ['-f'], desc: 'Read a dump from file with provided name'
        option :annotate, type: :boolean, aliases: ['-a'], desc: 'Print a table with annonated tokens'

        def call(**options)
          dump = options[:file] ? File.read(options[:file]) : STDIN.read
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

        def call(**options)
          puts "Run ast"
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
