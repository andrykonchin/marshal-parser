# marshal-parser

`marshal-parser` is a library that allows you to read and analyze data
that has been serialized in Ruby's Marshal format. It is built for
educational purposes, but can also be a handy tool for learning the
Marshal format or even for investigating bugs in its implementation.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'marshal-parser'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install marshal-parser

## What is the Marshal format?

The Marshal format is a binary format used in Ruby to serialize Ruby
objects. The format can store arbitrary objects through three
user-defined extension mechanisms. The serialized data can be stored in
a file or transmitted over a network, and then deserialized back into a
Ruby object.

The Marshal format is described here <https://ruby-doc.org/core-3.1.0/doc/marshal_rdoc.html>.

There are also a lot of articles that could be useful, for instance:
- <https://shopify.engineering/caching-without-marshal-part-one>
- <https://iliabylich.github.io/2016/01/25/ruby-marshalling-from-a-to-z.html>
- <http://jakegoulding.com/blog/categories/marshal/>

## Features

There are a couple of uniq features that makes it stand out from the
croud:

- comprehensive support of the Marshal format
- CLI to parse existing dumps
- several output formats with different detalization levels

## Usage

The primary way to use `marshal-parser` is to run the CLI script `marshal-cli`.

### Tokens

To print tokens separated by whitespaces, use the `tokens` command,
followed by the `--evaluate` flag and a Ruby expression which value you
want to dump and parse:

    marshal-cli tokens --evaluate '[true, false, 0]'

This will output:

    "\x04\b" [ "\b" T F i "\x00"

To print descriptions for each token, use the `--annotate` flag:

    marshal-cli tokens --evaluate '[true, false, 0]' --annotate

This will output:

    "\x04\b"   - Version (4.8)
    "["        - Array beginning
    "\b"       - Integer encoded (3)
    "T"        - true
    "F"        - false
    "i"        - Integer beginning
    "\x00"     - Integer encoded (0)

### AST

To print the AST or structure of a Marshal dump, use the `ast` command,
followed by the `--evaluate` flag:

    marshal-cli ast --evaluate '[true, false, 0]'

This will output:

    (array
      (length 3)
      (true)
      (false)
      (integer
        (value 0)))

The AST is printed in a kind of S-expressions form. Both nodes (e.g. `array`,
`integer`...) and attributes (`length`) are printed.

To print only the nodes, use the `--compact` flag:

    marshal-cli --evaluate '[true, false, 0]' --compact

This will output:

    (array
      true
      false
      (integer 0))

To print the AST as tokens, use the `--only-tokens` option:

    marshal-cli ast --evaluate '[true, false, 0]' --only-tokens

This will output:

    [
      "\b"
      T
      F
      i "\x00"

### Other flags

To list all the available flags use the `--help` flag for each command:

    marshal-cli tokens --help
    marshal-cli ast --help
    marshal-cli --help

### Ruby library

To use `marshal-parser` as a Ruby library the following examples will be
useful:

Use `MarshalParser::Lexer` class to get tokens:

```ruby
require 'marshal-parser'

dump = Marshal.dump(1)
lexer = MarshalParser::Lexer.new(dump)
lexer.run

pp lexer.tokens
```

This will output:

    [#<struct MarshalParser::Lexer::Token id=0, index=0, length=2, value="4.8">,
     #<struct MarshalParser::Lexer::Token id=14, index=2, length=1, value=nil>,
     #<struct MarshalParser::Lexer::Token id=25, index=3, length=1, value=1>]

Use `MarshalParser::Parser` class to get the AST:

```ruby
require 'marshal-parser'

dump = Marshal.dump(1)
lexer = MarshalParser::Lexer.new(dump)
lexer.run

parser = MarshalParser::Parser.new(lexer)
ast = parser.parse

pp ast
```

This will output:

    #<MarshalParser::Parser::IntegerNode:0x000000010daba4d8
     @prefix=#<struct MarshalParser::Lexer::Token id=14, index=2, length=1, value=nil>,
     @value=#<struct MarshalParser::Lexer::Token id=25, index=3, length=1, value=1>>

## Limitations

- Supports only the current Marshal format version (4.8)
- Does not support a deprecated node 'M' (that represents 'Class or Module')
- Does not support a 'd' node (Data object, that represents wrapped pointers from Ruby extensions)
- Doesn't print in annotations object indices (because Ruby is not consistent here and object indices assigning order may
vary depending on a class of a dumped object)

## Similar projects

There are several projects that might be interesting as well:
- <https://github.com/iliabylich/pure_ruby_marshal>
- <https://github.com/drbrain/marshal-structure>

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/andrykonchin/marshal-parser. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/andrykonchin/marshal-parser/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the marshal-parser project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/andrykonchin/marshal-parser/blob/master/CODE_OF_CONDUCT.md).
