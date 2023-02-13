module Lighthouse
  module LettersGenerator
    class Configuration
      include Singleton

      def service_name
        'Lighthouse_LettersGenerator'
      end
    end
  end
end