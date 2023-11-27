# frozen_string_literal: true

require_relative "lexer"
require_relative "assertable"

module MarshalParser
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
      build_ast_node
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
        @symbols << @lexer.source_string[content.index, content.length]

        SymbolNode.new(token, length, content, @symbols.size - 1)

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

      when Lexer::OBJECT_LINK_PREFIX
        index = next_token

        ObjectLinkNode.new(token, index)

      when Lexer::OBJECT_WITH_DUMP_PREFIX
        class_name_node = build_ast_node
        assert_node_type class_name_node, SymbolNode, SymbolLinkNode

        length = next_token
        user_dump = next_token

        ObjectWithDumpMethodNode.new(token, class_name_node, length, user_dump)

      when Lexer::OBJECT_WITH_MARSHAL_DUMP_PREFIX
        class_name_node = build_ast_node
        assert_node_type class_name_node, SymbolNode, SymbolLinkNode

        child_node = build_ast_node

        ObjectWithMarshalDumpMethod.new(token, class_name_node, child_node)

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
      @lexer.tokens[@index - 1]
    end

    def assert_node_type(node, *allowed_classes)
      assert(
        allowed_classes.any? { |node_class| node.instance_of?(node_class) },
        "Node #{node} should be a #{allowed_classes.map(&:name).join(" or ")}"
      )
    end

    def assert_token_type(token, *token_ids)
      assert(
        token_ids.include?(token.id),
        "Token #{token} should have type #{token_ids.join(" or ")}"
      )
    end

    module Annotatable
      def annotation
        raise "Not implemented"
      end
    end

    class Node
      include Assertable

      def child_entities
        raise "Not implemented"
      end

      def tokens
        child_entities.grep(Lexer::Token)
      end

      def children
        child_entities.grep(Node)
      end

      def decoded_value
        nil
      end

      def literal_token
        nil
      end

      def attributes
        {}
      end

      def always_leaf?
        false
      end

      private

      def assert_token_type(token, *token_ids)
        assert(
          token_ids.include?(token.id),
          "Token #{token} should have type #{token_ids.join(" or ")}"
        )
      end
    end

    class VersionNode < Node
      def initialize(version_token)
        super()
        assert_token_type version_token, Lexer::VERSION
        @version_token = version_token
      end

      def child_entities
        [@version_token]
      end
    end

    class ArrayNode < Node
      def initialize(marker_token, length_token, elements_nodes)
        super()
        assert_token_type marker_token, Lexer::ARRAY_PREFIX
        assert_token_type length_token, Lexer::INTEGER

        @marker_token = marker_token
        @length_token = length_token
        @elements_nodes = elements_nodes
      end

      def child_entities
        [@marker_token, @length_token] + @elements_nodes
      end

      def attributes
        {
          @length_token => { name: :length, value: @length_token.value }
        }
      end
    end

    class StringNode < Node
      def initialize(marker_token, length_token, content_token)
        super()
        assert_token_type marker_token, Lexer::STRING_PREFIX
        assert_token_type length_token, Lexer::INTEGER
        assert_token_type content_token, Lexer::STRING

        @marker_token = marker_token
        @length_token = length_token
        @content_token = content_token
      end

      def child_entities
        [@marker_token, @length_token, @content_token]
      end

      def literal_token
        @content_token
      end

      def attributes
        {
          @length_token => { name: :length, value: @length_token.value },
          @content_token => { name: :content, value: @content_token }
        }
      end
    end

    class ObjectWithIVarsNode < Node
      def initialize(marker_token, child, count_token, ivars_nodes)
        super()
        assert_token_type marker_token, Lexer::OBJECT_WITH_IVARS_PREFIX
        # child - any Node
        assert_token_type count_token, Lexer::INTEGER
        # ivars nodes - any nodes

        @marker_token = marker_token
        @child = child
        @count_token = count_token
        @ivars_nodes = ivars_nodes
      end

      def child_entities
        [@marker_token, @child, @count_token] + @ivars_nodes
      end

      def attributes
        {
          @count_token => { name: :ivars_count, value: @count_token.value }
        }
      end
    end

    class SymbolNode < Node
      include Annotatable

      def initialize(marker_token, length_token, content_token, link_to_symbol)
        super()
        assert_token_type marker_token, Lexer::SYMBOL_PREFIX
        assert_token_type length_token, Lexer::INTEGER
        assert_token_type content_token, Lexer::SYMBOL

        @marker_token = marker_token
        @length_token = length_token
        @content_token = content_token
        @link_to_symbol = link_to_symbol # just Integer, index in the Symbols table
      end

      def child_entities
        [@marker_token, @length_token, @content_token]
      end

      def annotation
        "symbol ##{@link_to_symbol}"
      end

      def literal_token
        @content_token
      end

      def attributes
        {
          @length_token => { name: :length, value: @length_token.value },
          @content_token => { name: :content, value: @content_token }
        }
      end
    end

    class TrueNode < Node
      def initialize(token)
        super()
        assert_token_type(token, Lexer::TRUE)
        @token = token
      end

      def child_entities
        [@token]
      end

      def always_leaf?
        true
      end
    end

    class FalseNode < Node
      def initialize(token)
        super()
        assert_token_type token, Lexer::FALSE
        @token = token
      end

      def child_entities
        [@token]
      end

      def always_leaf?
        true
      end
    end

    class NilNode < Node
      def initialize(token)
        super()
        assert_token_type token, Lexer::NIL
        @token = token
      end

      def child_entities
        [@token]
      end

      def always_leaf?
        true
      end
    end

    class IntegerNode < Node
      def initialize(prefix, value)
        super()
        assert_token_type prefix, Lexer::INTEGER_PREFIX
        assert_token_type value, Lexer::INTEGER

        @prefix = prefix
        @value = value
      end

      def child_entities
        [@prefix, @value]
      end

      def decoded_value
        @value.value
      end

      def literal_token
        @value
      end

      def attributes
        {
          @value => { name: :value, value: @value.value }
        }
      end
    end

    class BigIntegerNode < Node
      def initialize(prefix, sign, length, value)
        super()
        assert_token_type prefix, Lexer::BIG_INTEGER_PREFIX
        assert_token_type sign, Lexer::PLUS_SIGN, Lexer::MINUS_SIGN
        assert_token_type length, Lexer::INTEGER
        assert_token_type value, Lexer::BIG_INTEGER

        @prefix = prefix
        @sign = sign
        @length = length
        @value = value
      end

      def child_entities
        [@prefix, @sign, @length, @value]
      end

      def decoded_value
        @value.value
      end

      def literal_token
        @value
      end

      def attributes
        {
          @value => { name: :value, value: @value.value }
        }
      end
    end

    class FloatNode < Node
      def initialize(prefix, length, value)
        super()
        assert_token_type prefix, Lexer::FLOAT_PREFIX
        assert_token_type length, Lexer::INTEGER
        assert_token_type value, Lexer::FLOAT

        @prefix = prefix
        @length = length
        @value = value
      end

      def child_entities
        [@prefix, @length, @value]
      end

      def decoded_value
        @value.value
      end

      def literal_token
        @value
      end

      def attributes
        {
          @length => { name: :length, value: @length.value },
          @value => { name: :value, value: @value.value }
        }
      end
    end

    class SymbolLinkNode < Node
      include Annotatable

      def initialize(marker_token, index_token)
        super()
        assert_token_type marker_token, Lexer::SYMBOL_LINK_PREFIX
        assert_token_type index_token, Lexer::INTEGER

        @marker_token = marker_token
        @index_token = index_token
      end

      def child_entities
        [@marker_token, @index_token]
      end

      def annotation
        "link to symbol ##{@index_token.value}"
      end

      def decoded_value
        @index_token.value
      end

      def literal_token
        @index_token
      end

      def attributes
        {
          @index_token => { name: :index, value: @index_token.value }
        }
      end
    end

    class HashNode < Node
      def initialize(prefix, size, key_and_value_nodes)
        super()
        assert_token_type prefix, Lexer::HASH_PREFIX
        assert_token_type size, Lexer::INTEGER

        @prefix = prefix
        @size = size
        @key_and_value_nodes = key_and_value_nodes
      end

      def child_entities
        [@prefix, @size] + @key_and_value_nodes
      end

      def attributes
        {
          @size => { name: :size, value: @size.value }
        }
      end
    end

    class HashWithDefaultValueNode < Node
      def initialize(prefix, size, key_and_value_nodes, default_value_node)
        super()
        assert_token_type prefix, Lexer::HASH_WITH_DEFAULT_VALUE_PREFIX
        assert_token_type size, Lexer::INTEGER

        @prefix = prefix
        @size = size
        @key_and_value_nodes = key_and_value_nodes
        @default_value_node = default_value_node
      end

      def child_entities
        [@prefix, @size] + @key_and_value_nodes + [@default_value_node]
      end

      def attributes
        {
          @size => { name: :size, value: @size.value }
        }
      end
    end

    class RegexpNode < Node
      def initialize(prefix, string_length, string, options)
        super()
        assert_token_type prefix, Lexer::REGEXP_PREFIX
        assert_token_type string_length, Lexer::INTEGER
        assert_token_type string, Lexer::STRING
        assert_token_type options, Lexer::INTEGER

        @prefix = prefix
        @string_length = string_length
        @string = string
        @options = options
      end

      def child_entities
        [@prefix, @string_length, @string, @options]
      end

      def literal_token
        @string
      end

      def attributes
        {
          @string_length => { name: :length, value: @string_length.value },
          @string => { name: :source_string, value: @string },
          @options => { name: :options, value: @options.value }
        }
      end
    end

    class ClassNode < Node
      def initialize(prefix, length, name)
        super()
        assert_token_type prefix, Lexer::CLASS_PREFIX
        assert_token_type length, Lexer::INTEGER
        assert_token_type name, Lexer::STRING

        @prefix = prefix
        @length = length
        @name = name
      end

      def child_entities
        [@prefix, @length, @name]
      end

      def literal_token
        @name
      end

      def attributes
        {
          @length => { name: :length, value: @length.value },
          @name => { name: :name, value: @name }
        }
      end
    end

    class ModuleNode < Node
      def initialize(prefix, length, name)
        super()
        assert_token_type prefix, Lexer::MODULE_PREFIX
        assert_token_type length, Lexer::INTEGER
        assert_token_type name, Lexer::STRING

        @prefix = prefix
        @length = length
        @name = name
      end

      def child_entities
        [@prefix, @length, @name]
      end

      def literal_token
        @name
      end

      def attributes
        {
          @length => { name: :length, value: @length.value },
          @name => { name: :name, value: @name }
        }
      end
    end

    class SubclassNode < Node
      def initialize(prefix, class_name_node, object_node)
        super()
        assert_token_type prefix, Lexer::SUBCLASS_OF_CORE_LIBRARY_CLASS_PREFIX

        @prefix = prefix
        @class_name_node = class_name_node
        @object_node = object_node
      end

      def child_entities
        [@prefix, @class_name_node, @object_node]
      end
    end

    class StructNode < Node
      def initialize(prefix, class_name_node, members_count, member_nodes)
        super()
        assert_token_type prefix, Lexer::STRUCT_PREFIX
        assert_token_type members_count, Lexer::INTEGER

        @prefix = prefix
        @class_name_node = class_name_node
        @members_count = members_count
        @member_nodes = member_nodes
      end

      def child_entities
        [@prefix, @class_name_node, @members_count] + @member_nodes
      end

      def attributes
        {
          @members_count => { name: :count, value: @members_count.value }
        }
      end
    end

    class ObjectNode < Node
      def initialize(prefix, class_name_node, ivars_count, ivars_nodes)
        super()
        assert_token_type prefix, Lexer::OBJECT_PREFIX
        assert_token_type ivars_count, Lexer::INTEGER

        @prefix = prefix
        @class_name_node = class_name_node
        @ivars_count = ivars_count
        @ivars_nodes = ivars_nodes
      end

      def child_entities
        [@prefix, @class_name_node, @ivars_count] + @ivars_nodes
      end

      def attributes
        {
          @ivars_count => { name: :ivars_count, value: @ivars_count.value }
        }
      end
    end

    class ObjectLinkNode < Node
      def initialize(prefix, index)
        super()
        assert_token_type prefix, Lexer::OBJECT_LINK_PREFIX
        assert_token_type index, Lexer::INTEGER

        @prefix = prefix
        @index = index
      end

      def child_entities
        [@prefix, @index]
      end

      def decoded_value
        @index.value
      end

      def literal_token
        @index
      end

      def attributes
        {
          @index => { name: :index, value: @index.value }
        }
      end
    end

    class ObjectWithDumpMethodNode < Node
      def initialize(token, class_name_node, length, user_dump)
        super()
        assert_token_type token, Lexer::OBJECT_WITH_DUMP_PREFIX
        assert_token_type length, Lexer::INTEGER
        assert_token_type user_dump, Lexer::STRING

        @prefix = token
        @class_name_node = class_name_node
        @length = length
        @user_dump = user_dump
      end

      def child_entities
        [@prefix, @class_name_node, @length, @user_dump]
      end

      def literal_token
        @user_dump
      end

      def attributes
        {
          @length => { name: :length, value: @length.value },
          @user_dump => { name: :dump, value: @user_dump }
        }
      end
    end

    class ObjectWithMarshalDumpMethod < Node
      def initialize(prefix, class_name_node, child_node)
        super()
        assert_token_type prefix, Lexer::OBJECT_WITH_MARSHAL_DUMP_PREFIX

        @prefix = prefix
        @class_name_node = class_name_node
        @child_node = child_node
      end

      def child_entities
        [@prefix, @class_name_node, @child_node]
      end
    end

    class ObjectExtendedNode < Node
      def initialize(prefix, module_name_node, object_node)
        super()
        @prefix = prefix
        @module_name_node = module_name_node
        @object_node = object_node
      end

      def child_entities
        [@prefix, @module_name_node, @object_node]
      end
    end
  end
end
