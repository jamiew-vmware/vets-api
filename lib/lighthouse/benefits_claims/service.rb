# frozen_string_literal: true

require 'common/client/base'
require 'lighthouse/benefits_claims/configuration'
require 'lighthouse/benefits_claims/service_exception'

module BenefitsClaims
  class Service < Common::Client::Base
    configuration BenefitsClaims::Configuration
    STATSD_KEY_PREFIX = 'api.benefits_claims'

    def initialize(icn)
      @icn = '1012830905V768518'
      raise ArgumentError, 'no ICN passed in for LH API request.' if icn.blank?

      super()
    end

    def get_claims
      config.connection.get("#{@icn}/claims").body
    rescue Faraday::ClientError => e
      raise BenefitsClaims::ServiceException.new(e.response), 'Lighthouse Error'
    end

    def get_claim(id)
      config.connection.get("#{@icn}/claims/#{id}").body
    rescue Faraday::ClientError => e
      raise BenefitsClaims::ServiceException.new(e.response), 'Lighthouse Error'
    end
  end
end
