# frozen_string_literal: true

require 'common/client/base'
require 'dgi/contact_info/configuration'
require 'dgi/service'
require 'dgi/contact_info/response'
require 'authentication_token_service'

module MebApi
  module DGI
    module ContactInfo
      class Service < MebApi::DGI::Service
        configuration MebApi::DGI::ContactInfo::Configuration
        STATSD_KEY_PREFIX = 'api.dgi.contact_info'

        def check_for_duplicates(email, phone_numbers)
          with_monitoring do
            options = { timeout: 60 }
            # response = perform(:post, duplicates_end_point, { email: [email], phone_number: [phone_numbers] }.to_json, headers, options)
            # TODO: Update front end to handle multiple emails/phone numbers
            response = { 
              body: {
                email: [
                  {address: "vets.gov.meb.testuser+9@gmail.com", isDupe: "true"},
                  # {address: "e2.test@va.gov", isDupe: "false"},
                  # {address: "e2.test@va.gov", isDupe: "true"}
                ],
                phone: [
                  {number: "8013090123", isDupe: "false"},
                  # {number: "8013090234", isDupe: "false"},
                  # {number: "8013090345", isDupe: "true"}
                ]
              }
            }
            MebApi::DGI::ContactInfo::Response.new(200, response)
          end
        end

        private

        def duplicates_end_point
          'claimants/dupesCheck'
        end

        def headers
          {
            "Authorization": "Bearer #{MebApi::AuthenticationTokenService.call}"
          }
        end
      end
    end
  end
end
