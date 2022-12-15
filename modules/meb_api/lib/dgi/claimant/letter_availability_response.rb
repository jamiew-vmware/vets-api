# frozen_string_literal: true

require 'dgi/response'

module MebApi
  module DGI
    module Claimant
      class LetterAvailabilityResponse < MebApi::DGI::Response
        attribute :claimant_id, String

        def initialize(status, response = nil)
          attributes = {
            is_available: response.body
          }

          super(status, attributes)
        end
      end
    end
  end
end
