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
        puts e
        raise Lighthouse::LettersGenerator::ICNNotFoundError.new(e.message)
      end
    end
  end
end