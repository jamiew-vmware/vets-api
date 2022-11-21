module Mobile
  module V0
    module LighthouseLetters

      class Service < Common::Client::Base
        configuration Configuration

        def initialize(user)
          @user = user
        end

        def get_letters
          perform(:get, 'eligible-letters', params, headers)
        end

        def headers
          config.base_request_headers.merge(Authorization: "Bearer #{access_token}")
        end

        def params
          { icn: @user.icn }
        end

        def access_token
          cached_session = LighthouseSession.get_cached(@user)
          return cached_session.access_token if cached_session

          params = LighthouseParamsFactory.new(@user.icn, :letters).build
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
