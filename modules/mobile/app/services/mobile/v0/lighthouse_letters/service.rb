# frozen_string_literal: true

module Mobile
  module V0
    module LighthouseLetters
      # Service that connects to VA Lighthouse's Veteran Health FHIR API
      # https://developer.va.gov/explore/health/docs/fhir?version=current
      #
      class Service < Common::Client::Base
        configuration Configuration

        # @param user IAMUser the user requesting the records
        #
        def initialize(user)
          @user = user
        end

        # Performs a query for a list of eligible letters for a veteran
        # by ICN (identified in the access token)
        #
        # @return Hash the list of letters decoded from JSON
        #
        def get_letters
          response = perform(:get, 'eligible-letters', params, headers)
          response.body
        end

        private

        def headers
          config.base_request_headers.merge(Authorization: "Bearer #{access_token}")
        end

        def params
          { icn: @user.icn }
        end

        def access_token
          cached_session = LighthouseSession.get_cached(@user)
          return cached_session.access_token if cached_session

          params = LighthouseParamsFactory.new(@user.icn,'letters').build
          response = config.access_token_connection.post('', params)
          token_hash = response.body
          session = LighthouseSession.new(token_hash.symbolize_keys)
          LighthouseSession.set_cached(@user, session, session.expires_in)
          session.access_token
        end
      end
    end
  end
end
