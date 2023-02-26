module MarshalCLI
  module Assertable
    def assert(boolean, message)
      raise "Assert failed: #{message}" unless boolean
    end
  end
end
