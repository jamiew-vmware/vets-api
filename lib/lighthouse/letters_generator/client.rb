require 'lighthouse/letters_generator/configuration'

module Lighthouse
  module LettersGenerator
    class Client < Common::Client::Base
      configuration Lighthouse::LettersGenerator::Configuration

      def get_eligible_letter_types(icn)
        response = get("/eligible-letters", {icn: icn}, {}, {})
        # byebug # when I inspect here for the 400 test, I can see the 400 response coming back
        response.body["letters"]
      rescue Faraday::BadRequestError => e
        # Note for Kevin: this error never seems to get raised by Faraday
        # but I've inspected the response and confirmed that the 400
        # response comes through
        byebug 
      end
    end
  end
end