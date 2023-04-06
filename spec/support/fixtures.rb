# frozen_string_literal: true

class ArraySubclass < Array
end

class StringSubclass < String
end

class HashSubclass < Hash
end

class RegexpSubclass < Regexp
end

StructA = Struct.new(:a)

class UserDefined
  attr_reader :a, :b

  def self.load(string)
    a, b = string.split(":")
    new(a.to_i, b.to_i)
  end

  def initialize(a, b)
    @a = a
    @b = b
  end

  def _dump(_level)
    "#{@a}:#{@b}"
  end
end

class UserMarshal
  def initialize(a, b)
    @a = a
    @b = b
  end

  def marshal_dump
    [@a, @b]
  end

  def marshal_load(object)
    @a, @b = object
  end
end
