class BeLikeAST
  def initialize(expected)
    @expected = expected
  end

  def matches?(actual)
    @actual = actual

    nodes_match?(actual, @expected)
  end

  def failure_message
    "#{@actual} doesn't match expected #{@expected}"
  end

  private

  def nodes_match?(actual, expected)
    case expected
    when Class
      #puts "=== compare #{actual.class} and #{expected}"
      actual.class == expected
    when Hash
      key = expected.keys[0]
      value = expected.values[0]

      return false unless actual.is_a?(key)

      if value.is_a?(Array)
        # several expectations for the same node:
        # - on children,
        # - on literal or computed value
        value.all? do |expectation|
          if expectation.respond_to?(:matches?)
            expectation.matches?(actual)
          else
            BeLikeAST.new(expectation).matches?(actual)
          end
        end
      elsif value.respond_to?(:matches?)
        # literal/computed value expectation
        # e.g. raw value of String, Symbol or Class/Module name
        # or decoded Integer, Float, Big Integer
        value.matches?(actual)
      else
        raise "Unsupported expected Hash value #{value} (expected - #{expected})"
      end
    else
      raise "Unsupported expected value #{expected}"
    end
  end
end

def be_like_ast(ast)
  BeLikeAST.new(ast)
end
