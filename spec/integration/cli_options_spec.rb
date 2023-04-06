# frozen_string_literal: true

require "tempfile"

RSpec.describe "bin/marshal-cli options" do
  describe "tokens" do
    it "reads dump from stdin and prints tokens separated with whitespaces" do
      command = 'ruby -e "puts Marshal.dump(:symbol)" | ruby -Ilib bin/marshal-cli tokens'
      expect(`#{command}`.chomp).to eql('"\x04\b" : "\v" symbol')
    end

    context "--file option" do
      it "reads dump from file" do
        dump = Marshal.dump(:symbol)

        file = Tempfile.new("marshal-dump", encoding: "ASCII-8BIT")
        file.write(dump)
        file.close

        command = "ruby -Ilib bin/marshal-cli tokens --file #{file.path}"
        expect(`#{command}`.chomp).to eql('"\x04\b" : "\v" symbol')
      ensure
        file.unlink
      end
    end

    context "--evaluate option" do
      it "executes a Ruby code-snipet and dumps result object with Marshal.dump" do
        command = 'ruby -Ilib bin/marshal-cli tokens --evaluate ":symbol"'
        expect(`#{command}`.chomp).to eql('"\x04\b" : "\v" symbol')
      end
    end

    context "--annotate option" do
      it "prints tokens as a table and provides description for every token" do
        command = 'ruby -e "puts Marshal.dump(:symbol)" | ruby -Ilib bin/marshal-cli tokens --annotate'
        expect(`#{command}`).to eql(<<~'STR')
          "\x04\b"   - Version (4.8)
          ":"        - Symbol beginning
          "\v"       - Integer encoded (6)
          "symbol"   - Symbol characters
        STR
      end
    end

    context "--help" do
      it "prints description and options" do
        command = "ruby -Ilib bin/marshal-cli tokens --help"
        expect(`#{command} 2>&1`).to eql(<<~STR)
          Command:
            marshal-cli tokens

          Usage:
            marshal-cli tokens

          Description:
            Parse a dump and print tokens. By default reads dump from the stdin.

          Options:
            --file=VALUE, -f VALUE            # Read a dump from file with provided name
            --evaluate=VALUE, -e VALUE        # Ruby expression to dump
            --[no-]annotate, -a               # Print a table with annonated tokens
            --help, -h                        # Print this help
        STR
      end
    end
  end

  describe "ast" do
    it "prints AST with node attributes as S-expression" do
      command = 'ruby -e "puts Marshal.dump(:symbol)" | ruby -Ilib bin/marshal-cli ast'
      expect(`#{command}`).to eql(<<~STR)
        (symbol
          (length 6)
          (content "symbol"))
      STR
    end

    context "--file option" do
      it "reads dump from file" do
        dump = Marshal.dump(:symbol)

        file = Tempfile.new("marshal-dump", encoding: "ASCII-8BIT")
        file.write(dump)
        file.close

        command = "ruby -Ilib bin/marshal-cli ast --file #{file.path}"
        expect(`#{command}`).to eql(<<~STR)
          (symbol
            (length 6)
            (content "symbol"))
        STR
      ensure
        file.unlink
      end
    end

    context "--evaluate option" do
      it "executes a Ruby code-snipet and dumps result object with Marshal.dump" do
        command = 'ruby -Ilib bin/marshal-cli ast --evaluate ":symbol"'
        expect(`#{command}`).to eql(<<~STR)
          (symbol
            (length 6)
            (content "symbol"))
        STR
      end
    end

    context "--only-tokens" do
      it "prints tokens instead of S-expression" do
        command = 'ruby -e "puts Marshal.dump([1, true, :symbol])" | ruby -Ilib bin/marshal-cli ast --only-tokens'
        expect(`#{command}`).to eql(<<~'STR')
          [
            "\b"
            i "\x06"
            T
            : "\v" symbol
        STR
      end

      it "prints annotation when --annotate option specified" do
        command = 'ruby -e "puts Marshal.dump([1, true, :symbol])" | ruby -Ilib bin/marshal-cli ast --only-tokens --annotate'
        expect(`#{command}`).to eql(<<~'STR')
          [
            "\b"
            i "\x06"
            T
            : "\v" symbol                                    # symbol #0
        STR
      end
    end

    context "--annotate option" do
      it "prints additional description for some nodes in the right hand side column" do
        command = 'ruby -e "puts Marshal.dump([1, true, :symbol])" | ruby -Ilib bin/marshal-cli ast --annotate'
        expect(`#{command}`).to eql(<<~STR)
          (array
            (length 3)
            (integer
              (value 1))
            (true)
            (symbol                                          # symbol #0
              (length 6)
              (content "symbol")))
        STR
      end
    end

    context "--width" do
      it "prints annotation with specified indentation" do
        command = 'ruby -e "puts Marshal.dump([1, true, :symbol])" | ruby -Ilib bin/marshal-cli ast --annotate --width 25'
        expect(`#{command}`).to eql(<<~STR)
          (array
            (length 3)
            (integer
              (value 1))
            (true)
            (symbol                 # symbol #0
              (length 6)
              (content "symbol")))
        STR
      end
    end

    context "--symbols" do
      it "prints a Symbol table afterwards" do
        command = 'ruby -e "puts Marshal.dump([1, true, :symbol])" | ruby -Ilib bin/marshal-cli ast --symbols'
        expect(`#{command}`).to eql(<<~STR)
          (array
            (length 3)
            (integer
              (value 1))
            (true)
            (symbol
              (length 6)
              (content "symbol")))

          Symbols table:
          0    - :symbol
        STR
      end
    end

    context "--compact" do
      it "doesn't print node attributes and additional information" do
        command = 'ruby -e "puts Marshal.dump([1, true, :symbol])" | ruby -Ilib bin/marshal-cli ast --compact'
        expect(`#{command}`).to eql(<<~STR)
          (array
            (integer 1)
            true
            (symbol "symbol"))
        STR
      end

      it "prints annotation when --annotate option specified" do
        command = 'ruby -e "puts Marshal.dump([1, true, :symbol])" | ruby -Ilib bin/marshal-cli ast --compact --annotate'
        expect(`#{command}`).to eql(<<~STR)
          (array
            (integer 1)
            true
            (symbol "symbol"))                               # symbol #0
        STR
      end
    end

    context "--help" do
      it "prints description and options" do
        command = "ruby -Ilib bin/marshal-cli ast --help"
        expect(`#{command} 2>&1`).to eql(<<~STR)
          Command:
            marshal-cli ast

          Usage:
            marshal-cli ast

          Description:
            Parse a dump and print AST. By default reads dump from the stdin and uses S-expressions format.

          Options:
            --file=VALUE, -f VALUE            # Read a dump from file with provided name
            --evaluate=VALUE, -e VALUE        # Ruby expression to dump
            --[no-]only-tokens, -o            # Print only tokens
            --[no-]annotate, -a               # Print annotations
            --width=VALUE, -w VALUE           # Width of the column with AST, used with --annotate
            --[no-]symbols, -s                # Print a table of symbols
            --[no-]compact, -c                # Don't print node attributes
            --help, -h                        # Print this help
        STR
      end
    end
  end

  describe "--help" do
    it "prints the list of commands" do
      command = "ruby -Ilib bin/marshal-cli --help"
      expect(`#{command} 2>&1`).to eql(<<~STR)
        Commands:
          marshal-cli ast               # Parse a dump and print AST. By default reads dump from the stdin and uses S-expressions format.
          marshal-cli tokens            # Parse a dump and print tokens. By default reads dump from the stdin.
          marshal-cli version           # Print version
      STR
    end
  end
end
