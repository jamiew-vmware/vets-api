# frozen_string_literal: true
require_relative 'configuration'

module Mobile
  module V0
    module LighthouseDirectDeposit
      # Service that connects to VA Lighthouse's Veteran Health FHIR API
      # https://developer.va.gov/explore/health/docs/fhir?version=current
      class Service < ::DirectDeposit::Client
        configuration Configuration
      end
    end
  end
end
