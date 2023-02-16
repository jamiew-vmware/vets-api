require 'lighthouse/letters_generator/configuration'

module Lighthouse
  module LettersGenerator
    class Client < Common::Client::Base
      configuration Lighthouse::LettersGenerator::Configuration

      def get_eligible_letter_types(icn)
        response = get("/eligible-letters", {icn: icn}, {}, {})
        response.body["letters"]
      end
    end
  end
end