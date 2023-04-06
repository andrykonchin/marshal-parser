# frozen_string_literal: true

class HasEncodedValue
  def initialize(expected)
    @expected = expected
  end

  def matches?(actual)
    @actual = actual

    actual.decoded_value == @expected
  end

  def failure_message
    "#{@actual} doesn't match expected #{@expected}"
  end
end

def has_encoded_value(expected)
  HasEncodedValue.new(expected)
end

def encoded_value(expected)
  HasEncodedValue.new(expected)
end
