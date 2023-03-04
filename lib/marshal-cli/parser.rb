require_relative 'lexer'
require_relative 'assertable'

module MarshalCLI
  class Parser
    include Assertable

    attr_reader :symbols

    def initialize(lexer)
      @lexer = lexer
      @index = 0
      @symbols = []
    end

    def parse
      version_node = build_ast_node
      root_node = build_ast_node
      root_node
    end

    private

    def build_ast_node
      token = next_token

      case token.id
      when Lexer::VERSION
        VersionNode.new(token)

      when Lexer::ARRAY_PREFIX
        length = next_token
        elements = []

        length.value.times do
          elements << build_ast_node
        end

        ArrayNode.new(token, length, elements)

      when Lexer::STRING_PREFIX
        length = next_token
        content = next_token

        StringNode.new(token, length, content)

      when Lexer::OBJECT_WITH_IVARS_PREFIX
        child = build_ast_node

        count = next_token
        assert_token_type(count, Lexer::INTEGER)

        ivars = []

        count.value.times do
          name = build_ast_node
          value = build_ast_node
          ivars << name << value

          assert_node_type(name, SymbolNode, SymbolLinkNode)
        end

        ObjectWithIVarsNode.new(token, child, count, ivars)

      when Lexer::SYMBOL_PREFIX
        length = next_token
        content = next_token
        @symbols << content.value

        SymbolNode.new(token, length, content, @symbols.size-1)

      when Lexer::TRUE
        TrueNode.new(token)

      when Lexer::FALSE
        FalseNode.new(token)

      when Lexer::NIL
        NilNode.new(token)

      when Lexer::INTEGER_PREFIX
        value = next_token
        IntegerNode.new(token, value)

      when Lexer::BIG_INTEGER_PREFIX
        sign = next_token
        length = next_token
        value = next_token
        BigIntegerNode.new(token, sign, length, value)

      when Lexer::FLOAT_PREFIX
        length = next_token
        value = next_token
        FloatNode.new(token, length, value)

      when Lexer::SYMBOL_LINK_PREFIX
        index = next_token

        SymbolLinkNode.new(token, index)

      when Lexer::HASH_PREFIX
        size = next_token
        assert_token_type size, Lexer::INTEGER

        key_and_value_nodes = []

        size.value.times do
          key = build_ast_node
          assert_node_type key, SymbolNode, SymbolLinkNode

          value = build_ast_node
          key_and_value_nodes << key << value
        end

        HashNode.new(token, size, key_and_value_nodes)

      when Lexer::HASH_WITH_DEFAULT_VALUE_PREFIX
        size = next_token
        assert_token_type size, Lexer::INTEGER

        key_and_value_nodes = []

        size.value.times do
          key = build_ast_node
          assert_node_type key, SymbolNode, SymbolLinkNode

          value = build_ast_node
          key_and_value_nodes << key << value
        end

        default_value_node = build_ast_node
        assert_node_type default_value_node, IntegerNode

        HashWithDefaultValueNode.new(token, size, key_and_value_nodes, default_value_node)

      when Lexer::REGEXP_PREFIX
        string_length = next_token
        string = next_token
        options = next_token

        RegexpNode.new(token, string_length, string, options)

      when Lexer::CLASS_PREFIX
        length = next_token
        string = next_token

        ClassNode.new(token, length, string)

      when Lexer::MODULE_PREFIX
        length = next_token
        string = next_token

        ModuleNode.new(token, length, string)

      when Lexer::SUBCLASS_OF_CORE_LIBRARY_CLASS_PREFIX
        class_name_node = build_ast_node
        assert_node_type class_name_node, SymbolNode, SymbolLinkNode

        object_node = build_ast_node

        SubclassNode.new(token, class_name_node, object_node)

      when Lexer::STRUCT_PREFIX
        class_name_node = build_ast_node
        assert_node_type class_name_node, SymbolNode, SymbolLinkNode

        members_count = next_token

        member_nodes = []

        members_count.value.times do
          name = build_ast_node
          value = build_ast_node

          assert_node_type name, SymbolNode, SymbolLinkNode

          member_nodes << name << value
        end

        StructNode.new(token, class_name_node, members_count, member_nodes)

      when Lexer::OBJECT_PREFIX
        class_name_node = build_ast_node
        assert_node_type class_name_node, SymbolNode, SymbolLinkNode

        ivars_count = next_token
        assert_token_type(ivars_count, Lexer::INTEGER)

        ivars_nodes = []

        ivars_count.value.times do
          name = build_ast_node
          value = build_ast_node

          ivars_nodes << name << value
        end

        ObjectNode.new(token, class_name_node, ivars_count, ivars_nodes)

      when Lexer::OBJECT_WITH_DUMP_PREFIX
        class_name_node = build_ast_node
        assert_node_type class_name_node, SymbolNode, SymbolLinkNode

        length = next_token
        user_dump = next_token

        ObjectWithDumpNode.new(token, class_name_node, length, user_dump)

      when Lexer::OBJECT_WITH_MARSHAL_DUMP_PREFIX
        class_name_node = build_ast_node
        assert_node_type class_name_node, SymbolNode, SymbolLinkNode

        child_node = build_ast_node

        ObjectWithMarshalDump.new(token, class_name_node, child_node)

      when Lexer::OBJECT_EXTENDED_PREFIX
        module_name_node = build_ast_node
        object_node = build_ast_node

        ObjectExtendedNode.new(token, module_name_node, object_node)

      else
        raise "Not supported token id #{token.id}"
      end
    end

    def next_token
      raise "No next token" if @index >= @lexer.tokens.size

      @index += 1
      @lexer.tokens[@index-1]
    end

    def assert_node_type(node, *allowed_classes)
      assert(
        allowed_classes.any? { |node_class| node_class === node },
        "Node #{node} should be a #{allowed_classes.map(&:name).join(' or ')}")
    end

    def assert_token_type(token, *token_ids)
      assert(
        token_ids.include?(token.id),
        "Token #{token} should have type #{token_ids.join(' or ')}")
    end

    class Node
      include Assertable

      def tokens
        []
      end

      def children
        []
      end

      def decoded_value
        nil
      end

      def literal_token
        raise 'Not implemented'
      end

      private

      def assert_token_type(token, *token_ids)
        assert(
          token_ids.include?(token.id),
          "Token #{token} should have type #{token_ids.join(' or ')}")
      end
    end

    class VersionNode < Node
      def initialize(version_token)
        assert_token_type version_token, Lexer::VERSION
        @version_token = version_token
      end

      def tokens
        [@version_token]
      end
    end

    module Annotatable
      def annotation
        raise "Not implemented"
      end
    end

    class ArrayNode < Node
      def initialize(marker_token, length_token, elements_nodes)
        assert_token_type marker_token, Lexer::ARRAY_PREFIX
        assert_token_type length_token, Lexer::INTEGER

        @marker_token = marker_token
        @length_token = length_token
        @elements_nodes = elements_nodes
      end

      def tokens
        [@marker_token, @length_token]
      end

      def children
        @elements_nodes
      end
    end

    class StringNode < Node
      def initialize(marker_token, length_token, content_token)
        assert_token_type marker_token, Lexer::STRING_PREFIX
        assert_token_type length_token, Lexer::INTEGER
        assert_token_type content_token, Lexer::STRING

        @marker_token = marker_token
        @length_token = length_token
        @content_token = content_token
      end

      def tokens
        [@marker_token, @length_token, @content_token]
      end

      def literal_token
        @content_token
      end
    end

    class ObjectWithIVarsNode < Node
      def initialize(marker_token, child, count_token, ivars_nodes)
        assert_token_type marker_token, Lexer::OBJECT_WITH_IVARS_PREFIX
        # child - any Node
        assert_token_type count_token, Lexer::INTEGER
        # ivars nodes - any nodes

        @marker_token = marker_token
        @child = child
        @count_token = count_token
        @ivars_nodes = ivars_nodes
      end

      def tokens
        [@marker_token, @count_token]
      end

      def children
        [@child] + @ivars_nodes
      end
    end

    class SymbolNode < Node
      include Annotatable

      def initialize(marker_token, length_token, content_token, link_to_symbol)
        assert_token_type marker_token, Lexer::SYMBOL_PREFIX
        assert_token_type length_token, Lexer::INTEGER
        assert_token_type content_token, Lexer::SYMBOL

        @marker_token = marker_token
        @length_token = length_token
        @content_token = content_token
        @link_to_symbol = link_to_symbol # just Integer, index in the Symbols table
      end

      def tokens
        [@marker_token, @length_token, @content_token]
      end

      def annotation
        "symbol ##{@symbol_number}"
      end

      def literal_token
        @content_token
      end
    end

    class TrueNode < Node
      def initialize(token)
        assert_token_type(token, Lexer::TRUE)
        @token = token
      end

      def tokens
        [@token]
      end
    end

    class FalseNode < Node
      def initialize(token)
        assert_token_type token, Lexer::FALSE
        @token = token
      end

      def tokens
        [@token]
      end
    end

    class NilNode < Node
      def initialize(token)
        assert_token_type token, Lexer::NIL
        @token = token
      end

      def tokens
        [@token]
      end
    end

    class IntegerNode < Node
      def initialize(prefix, value)
        assert_token_type prefix, Lexer::INTEGER_PREFIX
        assert_token_type value, Lexer::INTEGER

        @prefix = prefix
        @value = value
      end

      def tokens
        [@prefix, @value]
      end

      def decoded_value
        @value.value
      end
    end

    class BigIntegerNode < Node
      def initialize(prefix, sign, length, value)
        assert_token_type prefix, Lexer::BIG_INTEGER_PREFIX
        assert_token_type sign, Lexer::PLUS_SIGN, Lexer::MINUS_SIGN
        assert_token_type length, Lexer::INTEGER
        assert_token_type value, Lexer::BIG_INTEGER

        @prefix = prefix
        @sign = sign
        @length = length
        @value = value
      end

      def tokens
        [@prefix, @sign, @length, @value]
      end

      def decoded_value
        @value.value
      end
    end

    class FloatNode < Node
      def initialize(prefix, length, value)
        assert_token_type prefix, Lexer::FLOAT_PREFIX
        assert_token_type length, Lexer::INTEGER
        assert_token_type value, Lexer::FLOAT

        @prefix = prefix
        @length = length
        @value = value
      end

      def tokens
        [@prefix, @length, @value]
      end

      def decoded_value
        @value.value
      end
    end

    class SymbolLinkNode < Node
      include Annotatable

      def initialize(marker_token, index_token)
        assert_token_type marker_token, Lexer::SYMBOL_LINK_PREFIX
        assert_token_type index_token, Lexer::INTEGER

        @marker_token = marker_token
        @index_token = index_token
      end

      def tokens
        [@marker_token, @index_token]
      end

      def annotation
        "link to symbol ##{@index_token.value}"
      end

      def decoded_value
        @index_token.value
      end
    end

    class HashNode < Node
      def initialize(prefix, size, key_and_value_nodes)
        assert_token_type prefix, Lexer::HASH_PREFIX
        assert_token_type size, Lexer::INTEGER

        @prefix = prefix
        @size = size
        @key_and_value_nodes = key_and_value_nodes
      end

      def tokens
        [@prefix, @size]
      end

      def children
        @key_and_value_nodes
      end
    end

    class HashWithDefaultValueNode < Node
      def initialize(prefix, size, key_and_value_nodes, default_value_node)
        assert_token_type prefix, Lexer::HASH_WITH_DEFAULT_VALUE_PREFIX
        assert_token_type size, Lexer::INTEGER

        @prefix = prefix
        @size = size
        @key_and_value_nodes = key_and_value_nodes
        @default_value_node = default_value_node
      end

      def tokens
        [@prefix, @size]
      end

      def children
        @key_and_value_nodes + [@default_value_node]
      end
    end

    class RegexpNode < Node
      def initialize(prefix, string_length, string, options)
        assert_token_type prefix, Lexer::REGEXP_PREFIX
        assert_token_type string_length, Lexer::INTEGER
        assert_token_type string, Lexer::STRING
        assert_token_type options, Lexer::INTEGER

        @prefix = prefix
        @string_length = string_length
        @string = string
        @options = options
      end

      def tokens
        [@prefix, @string_length, @string, @options]
      end

      def literal_token
        @string
      end
    end

    class ClassNode < Node
      def initialize(prefix, length, name)
        assert_token_type prefix, Lexer::CLASS_PREFIX
        assert_token_type length, Lexer::INTEGER
        assert_token_type name, Lexer::STRING

        @prefix = prefix
        @length = length
        @name = name
      end

      def tokens
        [@prefix, @length, @name]
      end

      def literal_token
        @name
      end
    end

    class ModuleNode < Node
      def initialize(prefix, length, name)
        assert_token_type prefix, Lexer::MODULE_PREFIX
        assert_token_type length, Lexer::INTEGER
        assert_token_type name, Lexer::STRING

        @prefix = prefix
        @length = length
        @name = name
      end

      def tokens
        [@prefix, @length, @name]
      end

      def literal_token
        @name
      end
    end

    class SubclassNode < Node
      def initialize(prefix, class_name_node, object_node)
        assert_token_type prefix, Lexer::SUBCLASS_OF_CORE_LIBRARY_CLASS_PREFIX

        @prefix = prefix
        @class_name_node = class_name_node
        @object_node = object_node
      end

      def tokens
        [@prefix]
      end

      def children
        [@class_name_node, @object_node]
      end
    end

    class StructNode < Node
      def initialize(prefix, class_name_node, members_count, member_nodes)
        assert_token_type prefix, Lexer::STRUCT_PREFIX
        assert_token_type members_count, Lexer::INTEGER

        @prefix = prefix
        @class_name_node = class_name_node
        @members_count = members_count
        @member_nodes = member_nodes
      end

      def tokens
        [@prefix, @member_nodes]
      end

      def children
        [@class_name_node] + @member_nodes
      end
    end

    class ObjectNode < Node
      def initialize(prefix, class_name_node, ivars_count, ivars_nodes)
        assert_token_type prefix, Lexer::OBJECT_PREFIX
        assert_token_type ivars_count, Lexer::INTEGER

        @prefix = prefix
        @class_name_node = class_name_node
        @ivars_count = ivars_count
        @ivars_nodes = ivars_nodes
      end

      def tokens
        [@prefix, @class_name_node, @ivars_count]
      end

      def children
        [@class_name_node] + @ivars_nodes
      end
    end

    class ObjectWithDumpNode < Node
      def initialize(token, class_name_node, length, user_dump)
        assert_token_type token, Lexer::OBJECT_WITH_DUMP_PREFIX
        assert_token_type length, Lexer::INTEGER
        assert_token_type user_dump, Lexer::STRING

        @prefix = token
        @class_name_node = class_name_node
        @length = length
        @user_dump = user_dump
      end

      def tokens
        [@prefix, @length, @user_dump]
      end

      def children
        [@class_name_node]
      end

      def literal_token
        @user_dump
      end
    end

    class ObjectWithMarshalDump < Node
      def initialize(prefix, class_name_node, child_node)
        assert_token_type prefix, Lexer::OBJECT_WITH_MARSHAL_DUMP_PREFIX

        @prefix = prefix
        @class_name_node = class_name_node
        @child_node = child_node
      end

      def tokens
        [@prefix]
      end

      def children
        [@class_name_node, @child_node]
      end
    end

    class ObjectExtendedNode < Node
      def initialize(prefix, module_name_node, object_node)
        @prefix = prefix
        @module_name_node = module_name_node
        @object_node = object_node
      end

      def tokens
        [@prefix]
      end

      def children
        [@module_name_node, @object_node]
      end
    end

    class SymbolsTable
      def initialize(symbols)
        @symbols = symbols
      end

      def string
        @symbols.map.with_index do |symbol, i|
          "%-4d - :%s" % [i, symbol]
        end.join("\n")
      end
    end
  end
end
