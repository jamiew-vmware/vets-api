# frozen_string_literal: true

require 'common/client/base'
require 'lighthouse/benefits_claims/configuration'
require 'lighthouse/benefits_claims/service_exception'
require 'lighthouse/service_exception'

module BenefitsClaims
  class Service < Common::Client::Base
    configuration BenefitsClaims::Configuration
    STATSD_KEY_PREFIX = 'api.benefits_claims'

    def initialize(icn, ssn)
      @icn = icn
      @ssn = ssn
      raise ArgumentError, 'no ICN passed in for LH API request.' if icn.blank?
      raise ArgumentError, 'no SSN passed in for LH API request.' if ssn.blank?
    end

    def get_claims(lighthouse_client_id, lighthouse_rsa_key_path, options = {})
      config.get("#{@icn}/claims", lighthouse_client_id, lighthouse_rsa_key_path, options).body
    rescue Faraday::ClientError => e
      raise BenefitsClaims::ServiceException.new(e.response), 'Lighthouse Error'
    end

    def get_claim(id, lighthouse_client_id, lighthouse_rsa_key_path, options = {})
      config.get("#{@icn}/claims/#{id}", lighthouse_client_id, lighthouse_rsa_key_path, options).body
    rescue Faraday::ClientError => e
      raise BenefitsClaims::ServiceException.new(e.response), 'Lighthouse Error'
    end

    def get_intent_to_file(type, lighthouse_client_id, lighthouse_rsa_key_path, options = {})
      endpoint = 'benefits_claims/intent_to_file'
      path = "#{@icn}/intent-to-file/#{type}"
      config.get(path, lighthouse_client_id, lighthouse_rsa_key_path, options).body
    rescue Faraday::ClientError => e
      handle_error(e, lighthouse_client_id, endpoint)
    end

    # TODO: Check assumption, POST and rails services are secure, but make sure (using PII)
    # TODO: Type of Intent To File being submitted [ compensation, pension, survivor ]
    # For type "survivor", the request must include claimantSsn and be made by a valid Veteran Representative.
    # If the Representative is not a Veteran or a VA employee, this method is currently not available to them,
    # and they should use the Benefits Intake API as an alternative.
    def create_intent_to_file(type, lighthouse_client_id, lighthouse_rsa_key_path, options = {})
      endpoint = 'benefits_claims/intent_to_file'
      path = "#{@icn}/intent-to-file"
      puts "Attempting LH ITF post with type #{type} and icn #{@icn}"
      response = config.post(
        path,
        {
          type:,
          claimantSsn: @ssn
        },
        lighthouse_client_id, lighthouse_rsa_key_path, options
      ).body
      puts response
    rescue Faraday::ClientError => e
      handle_error(e, lighthouse_client_id, endpoint)
    end

    def handle_error(error, lighthouse_client_id, endpoint)
      Lighthouse::ServiceException.send_error(
        error,
        self.class.to_s.underscore,
        lighthouse_client_id,
        "#{config.base_api_path}/#{endpoint}"
      )
    end
  end
end
