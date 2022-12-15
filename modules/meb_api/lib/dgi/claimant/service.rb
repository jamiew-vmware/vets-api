# frozen_string_literal: true

require 'common/client/base'
require 'dgi/claimant/configuration'
require 'dgi/service'
require 'dgi/claimant/claimant_response'
require 'authentication_token_service'

module MebApi
  module DGI
    module Claimant
      class Service < MebApi::DGI::Service
        configuration MebApi::DGI::Claimant::Configuration
        STATSD_KEY_PREFIX = 'api.dgi.claimant'

        def get_claimant_info(type = 'Chapter33')
          with_monitoring do
            headers = request_headers
            options = { timeout: 60 }
            raw_response = perform(:post, end_point(type), { ssn: @user.ssn.to_s }.to_json, headers, options)

            MebApi::DGI::Claimant::ClaimantResponse.new(raw_response.status, raw_response)
          end
        end

        def get_letter_availability(claimant_id)
          with_monitoring do
            headers = request_headers
            options = { timeout: 60 }
            raw_response = perform(:post, letter_availability_endpoint(claimant_id, 'Chapter33'),
                                   { ssn: @user.ssn.to_s }.to_json, headers, options)

            MebApi::DGI::Claimant::LetterAvailabilityResponse.new(raw_response.status, raw_response)
          end
        end

        private

        # need to change function argument name: type -> claimantId
        def letter_availability_endpoint(claimant_id, type)
          "/claimant/#{claimant_id}/claimType/#{type}/letteravailabilitystatus"
        end

        def end_point(type)
          "claimType/#{type}/claimants/claimantId"
        end

        def request_headers
          {
            Authorization: "Bearer #{MebApi::AuthenticationTokenService.call}"
          }
        end
      end
    end
  end
end
