# frozen_string_literal: true

module MarshalParser
  module Formatters
    module Tokens
      class WithDescription
        def initialize(tokens, source_string)
          @tokens = tokens
          @source_string = source_string
        end

        def string
          @tokens.map do |token|
            string = @source_string[token.index, token.length].dump
            description = self.class.token_description(token.id)
            value = token.value ? " (#{token.value})" : ""

            "%-10s - %s%s" % [string, description, value]
          end.join("\n")
        end

        def self.token_description(token)
          case token
          when Lexer::VERSION                           then "Version"
          when Lexer::ARRAY_PREFIX                      then "Array beginning"
          when Lexer::OBJECT_WITH_IVARS_PREFIX          then "Special object with instance variables"
          when Lexer::OBJECT_WITH_DUMP_PREFIX           then "Object with #_dump and .load"
          when Lexer::OBJECT_WITH_MARSHAL_DUMP_PREFIX   then "Object with #marshal_dump and #marshal_load"
          when Lexer::STRING_PREFIX                     then "String beginning"
          when Lexer::HASH_PREFIX                       then "Hash beginning"
          when Lexer::HASH_WITH_DEFAULT_VALUE_PREFIX    then "Hash beginning (with default value)"
          when Lexer::REGEXP_PREFIX                     then "Regexp beginning"
          when Lexer::STRUCT_PREFIX                     then "Struct beginning"
          when Lexer::TRUE                              then "true"
          when Lexer::FALSE                             then "false"
          when Lexer::NIL                               then "nil"
          when Lexer::FLOAT_PREFIX                      then "Float beginning"
          when Lexer::INTEGER_PREFIX                    then "Integer beginning"
          when Lexer::BIG_INTEGER_PREFIX                then "Big Integer beginning"
          when Lexer::SYMBOL_PREFIX                     then "Symbol beginning"
          when Lexer::SYMBOL_LINK_PREFIX                then "Link to Symbol"
          when Lexer::CLASS_PREFIX                      then "Class beginning"
          when Lexer::MODULE_PREFIX                     then "Module beginning"
          when Lexer::OBJECT_PREFIX                     then "Object beginning"
          when Lexer::OBJECT_LINK_PREFIX                then "Link to object"
          when Lexer::OBJECT_EXTENDED_PREFIX            then "Object extended with a module"
          when Lexer::SUBCLASS_OF_CORE_LIBRARY_CLASS_PREFIX then "Instance of a Core Library class subclass beginning"
          when Lexer::FLOAT                             then "Float string representation"
          when Lexer::INTEGER                           then "Integer encoded"
          when Lexer::BIG_INTEGER                       then "Big Integer encoded"
          when Lexer::STRING                            then "String characters"
          when Lexer::SYMBOL                            then "Symbol characters"
          when Lexer::PLUS_SIGN                         then "Sign '+'"
          when Lexer::MINUS_SIGN                        then "Sign '-'"
          when Lexer::UNKNOWN_SIGN                      then "Unknown sign (internal error)"
          end
        end
      end
    end
  end
end
