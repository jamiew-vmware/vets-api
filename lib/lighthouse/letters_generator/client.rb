require 'lighthouse/letters_generator/configuration'

module Lighthouse
  module LettersGenerator
    class Client < Common::Client::Base
      configuration Lighthouse::LettersGenerator::Configuration

      def get_eligible_letter_types(icn)
        get("/eligible-letters", {icn: icn}, {}, {})
        letter_types = %w[A B C]
        letter_types
      end
    end
  end
end