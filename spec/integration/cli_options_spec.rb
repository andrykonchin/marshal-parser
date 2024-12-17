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

    context "--require option" do
      it "requires a specified source file" do
        path = "./spec/integration/fixtures/a.rb"

        command = "ruby -Ilib bin/marshal-cli tokens --require #{path} --evaluate ':symbol'"
        expect(`#{command}`).to eql(<<~'EOF'.b)
          Hello from a.rb
          "\x04\b" : "\v" symbol
        EOF
      end

      it "requires a specified file before evaluating code snippet when --evaluate option provided" do
        path = "./spec/integration/fixtures/b.rb"

        command = "ruby -Ilib bin/marshal-cli tokens --require #{path} --evaluate SYMBOL"
        expect(`#{command}`).to eql(<<~'EOF'.b)
          "\x04\b" : "\v" symbol
        EOF
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

    context "--hex option" do
      it "prints tokens in a hexadecimal encoding" do
        command = 'ruby -e "puts Marshal.dump(:symbol)" | ruby -Ilib bin/marshal-cli tokens --hex'
        expect(`#{command}`).to eql(<<~'STR')
          04 08  3A  0B  73 79 6D 62 6F 6C
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
            --require=VALUE, -r VALUE         # Load the library using require. It is useful when -e is specified
            --[no-]annotate, -a               # Print a table with annonated tokens
            --[no-]hex, -x                    # Print tokens in a hexadecimal encoding
            --help, -h                        # Print this help
        STR
      end
    end

    context "when --file option specified and binary content is invalid in the default encoding (UTF-8)" do
      it "emits proper output with default formatter" do
        time = Time.new(2024, 12, 17, 21, 59, 0, "+00:00")
        dump = Marshal.dump(time)

        file = Tempfile.new("marshal-dump", encoding: "ASCII-8BIT")
        file.write(dump)
        file.close

        command = "ruby -Ilib bin/marshal-cli tokens --file #{file.path}"
        expect(`#{command}`.chomp).to eql(<<~'STR'.chomp)
          "\x04\b" I u : "\t" Time "\r" "5.\x1F\x80\x00\x00\x00\xEC" "\a" : "\v" offset i "\x00" : "\t" zone 0
        STR
      ensure
        file.unlink
      end

      it "emits proper output with --annotate option" do
        time = Time.new(2024, 12, 17, 21, 59, 0, "+00:00")
        dump = Marshal.dump(time)

        file = Tempfile.new("marshal-dump", encoding: "ASCII-8BIT")
        file.write(dump)
        file.close

        command = "ruby -Ilib bin/marshal-cli tokens --file #{file.path} --annotate"
        expect(`#{command}`.chomp).to eql(<<~'STR'.chomp)
          "\x04\b"   - Version (4.8)
          "I"        - Special object with instance variables
          "u"        - Object with #_dump and .load
          ":"        - Symbol beginning
          "\t"       - Integer encoded (4)
          "Time"     - Symbol characters
          "\r"       - Integer encoded (8)
          "5.\x1F\x80\x00\x00\x00\xEC" - String characters
          "\a"       - Integer encoded (2)
          ":"        - Symbol beginning
          "\v"       - Integer encoded (6)
          "offset"   - Symbol characters
          "i"        - Integer beginning
          "\x00"     - Integer encoded (0)
          ":"        - Symbol beginning
          "\t"       - Integer encoded (4)
          "zone"     - Symbol characters
          "0"        - nil
        STR
      ensure
        file.unlink
      end

      it "emits proper output with --hex option" do
        time = Time.new(2024, 12, 17, 21, 59, 0, "+00:00")
        dump = Marshal.dump(time)

        file = Tempfile.new("marshal-dump", encoding: "ASCII-8BIT")
        file.write(dump)
        file.close

        command = "ruby -Ilib bin/marshal-cli tokens --file #{file.path} --hex"
        expect(`#{command}`.chomp).to eql(<<~STR.chomp)
          04 08  49  75  3A  09  54 69 6D 65  0D  35 2E 1F 80 00 00 00 EC  07  3A  0B  6F 66 66 73 65 74  69  00  3A  09  7A 6F 6E 65  30
        STR
      ensure
        file.unlink
      end
    end
  end

  describe "ast" do
    it "prints AST with node attributes as S-expression" do
      command = 'ruby -e "puts Marshal.dump(:symbol)" | ruby -Ilib bin/marshal-cli ast'
      expect(`#{command}`).to eql(<<~STR)
        (symbol
          (length 6)
          (bytes "symbol"))
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
            (bytes "symbol"))
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
            (bytes "symbol"))
        STR
      end
    end

    context "--require option" do
      it "requires a specified source file" do
        path = "./spec/integration/fixtures/a.rb"

        command = "ruby -Ilib bin/marshal-cli ast --require #{path} --evaluate ':symbol'"
        expect(`#{command}`).to eql(<<~EOF)
          Hello from a.rb
          (symbol
            (length 6)
            (bytes "symbol"))
        EOF
      end

      it "requires a specified file before evaluating code snippet when --evaluate option provided" do
        path = "./spec/integration/fixtures/b.rb"

        command = "ruby -Ilib bin/marshal-cli ast --require #{path} --evaluate SYMBOL"
        expect(`#{command}`).to eql(<<~EOF)
          (symbol
            (length 6)
            (bytes "symbol"))
        EOF
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
              (bytes "symbol")))
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
              (bytes "symbol")))
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
              (bytes "symbol")))

          Symbols table [1]:
          0 - :symbol
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
            --require=VALUE, -r VALUE         # Load the library using require. It is useful when -e is specified
            --[no-]only-tokens, -o            # Print only tokens
            --[no-]annotate, -a               # Print annotations
            --width=VALUE, -w VALUE           # Width of the column with AST, used with --annotate
            --[no-]symbols, -s                # Print a table of symbols
            --[no-]compact, -c                # Don't print node attributes
            --help, -h                        # Print this help
        STR
      end
    end

    context "when --file option specified and binary content is invalid in the default encoding (UTF-8)" do
      it "emits proper output with default formatter" do
        time = Time.new(2024, 12, 17, 21, 59, 0, "+00:00")
        dump = Marshal.dump(time)

        file = Tempfile.new("marshal-dump", encoding: "ASCII-8BIT")
        file.write(dump)
        file.close

        command = "ruby -Ilib bin/marshal-cli ast --file #{file.path}"
        expect(`#{command}`.chomp).to eql(<<~'STR'.chomp)
          (object-with-ivars
            (object-with-dump-method
              (symbol
                (length 4)
                (bytes "Time"))
              (length 8)
              (bytes "5.\x1F\x80\x00\x00\x00\xEC"))
            (ivars-count 2)
            (symbol
              (length 6)
              (bytes "offset"))
            (integer
              (value 0))
            (symbol
              (length 4)
              (bytes "zone"))
            (nil))
        STR
      ensure
        file.unlink
      end

      it "emits proper output with --only-tokens" do
        time = Time.new(2024, 12, 17, 21, 59, 0, "+00:00")
        dump = Marshal.dump(time)

        file = Tempfile.new("marshal-dump", encoding: "ASCII-8BIT")
        file.write(dump)
        file.close

        command = "ruby -Ilib bin/marshal-cli ast --file #{file.path} --only-tokens"
        expect(`#{command}`.chomp).to eql(<<~'STR'.chomp)
          I
            u
              : "\t" Time
              "\r"
              "5.\x1F\x80\x00\x00\x00\xEC"
            "\a"
            : "\v" offset
            i "\x00"
            : "\t" zone
            0
        STR
      end

      it "emits proper output with --annotate" do
        time = Time.new(2024, 12, 17, 21, 59, 0, "+00:00")
        dump = Marshal.dump(time)

        file = Tempfile.new("marshal-dump", encoding: "ASCII-8BIT")
        file.write(dump)
        file.close

        command = "ruby -Ilib bin/marshal-cli ast --file #{file.path} --annotate"
        expect(`#{command}`.chomp).to eql(<<~'STR'.chomp)
          (object-with-ivars
            (object-with-dump-method
              (symbol                                        # symbol #0
                (length 4)
                (bytes "Time"))
              (length 8)
              (bytes "5.\x1F\x80\x00\x00\x00\xEC"))
            (ivars-count 2)
            (symbol                                          # symbol #1
              (length 6)
              (bytes "offset"))
            (integer
              (value 0))
            (symbol                                          # symbol #2
              (length 4)
              (bytes "zone"))
            (nil))
        STR
      end

      it "emits proper output with --compact" do
        time = Time.new(2024, 12, 17, 21, 59, 0, "+00:00")
        dump = Marshal.dump(time)

        file = Tempfile.new("marshal-dump", encoding: "ASCII-8BIT")
        file.write(dump)
        file.close

        command = "ruby -Ilib bin/marshal-cli ast --file #{file.path} --compact"
        expect(`#{command}`.chomp).to eql(<<~'STR'.chomp)
          (object-with-ivars
            (object-with-dump-method
              (symbol "Time")
              "5.\x1F\x80\x00\x00\x00\xEC")
            (symbol "offset")
            (integer 0)
            (symbol "zone")
            nil)
        STR
      end
    end
  end

  describe "--help" do
    it "prints the list of commands" do
      command = "ruby -Ilib bin/marshal-cli --help"
      expect(`#{command} 2>&1`.chomp.chomp).to eql(<<~STR.chomp)
        Commands:
          marshal-cli ast               # Parse a dump and print AST. By default reads dump from the stdin and uses S-expressions format.
          marshal-cli tokens            # Parse a dump and print tokens. By default reads dump from the stdin.
          marshal-cli version           # Print version
      STR
    end
  end
end
