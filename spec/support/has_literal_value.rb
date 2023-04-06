# frozen_string_literal: true

class HasLiteralValue
  def initialize(expected, source_string)
    @expected = expected
    @source_string = source_string
  end

  def matches?(actual)
    @actual = actual

    token = actual.literal_token
    value = @source_string[token.index, token.length]

    # puts "#{value.dump} == #{@expected.dump}"
    value == @expected
  end

  def failure_message
    "#{@actual} doesn't match expected #{@expected}"
  end
end

def has_literal_value(expected, source_string)
  HasLiteralValue.new(expected, source_string)
end

def literal_value(expected, source_string)
  HasLiteralValue.new(expected, source_string)
end
