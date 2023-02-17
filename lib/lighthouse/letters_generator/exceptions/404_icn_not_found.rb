module Lighthouse
  module LettersGenerator
    class ICNNotFoundError < StandardError
      def initialize(msg = "Provided ICN not found")
        super(msg)
      end
    end
  end
end