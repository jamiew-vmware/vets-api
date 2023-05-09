# frozen_string_literal: true

require Rails.root.join(*%w[lib lighthouse direct_deposit configuration])

module Mobile
  module V0
    module LighthouseDirectDeposit
      # Configuration for the Mobile::V0::LighthouseDirectDeposit::Service
      #
      class Configuration < ::DirectDeposit::Configuration
        def service_name
          'MOBILE_LIGHTHOUSE_DIRECT_DEPOSIT'
        end

        def mobile_settings
          Settings.mobile_lighthouse
        end

        def token_service
          url = "#{settings.host}/#{TOKEN_PATH}"
          token = settings.access_token

          @token_service ||= Auth::ClientCredentials::Service.new(
            url, API_SCOPES, mobile_settings.client_id, token.aud_claim_url, mobile_settings.rsa_key
          )
        end
      end
    end
  end
end
