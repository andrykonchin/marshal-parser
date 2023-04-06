# frozen_string_literal: true

require_relative "be_like_ast"

class HasChildrenNodes
  def initialize(expected)
    @expected = expected
  end

  def matches?(actual)
    @actual = actual

    unless actual.children.size == @expected.size
      raise "Actual size of children (#{actual.children.size}) doesn't match expected value #{@expected}"
    end

    actual.children.zip(@expected).all? do |node, expectation|
      if expectation.respond_to?(:matches?)
        expectation.matches?(node)
      else
        BeLikeAST.new(expectation).matches?(node)
      end
    end
  end

  def failure_message
    "#{@actual} doesn't match expected #{@expected}"
  end
end

def has_children_nodes(*expected)
  HasChildrenNodes.new(expected)
end

def children_nodes(*expected)
  HasChildrenNodes.new(expected)
end
