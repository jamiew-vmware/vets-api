# frozen_string_literal: true

module SignIn
  class WellKnownGenerator
    def perform
      well_known_body
    end

    private

    def well_known_body
      end_points.merge(types).merge(methods)
    end

    def end_points
      {
        issuer: Settings.hostname,
        authorization_endpoint: "#{Settings.hostname}#{Constants::Auth::AUTHORIZATION_ROUTE_PATH}",
        token_endpoint: "#{Settings.hostname}#{Constants::Auth::TOKEN_ROUTE_PATH}",
        refresh_session_endpoint: "#{Settings.hostname}#{Constants::Auth::REFRESH_SESSION_ROUTE_PATH}",
        userinfo_endpoint: "#{Settings.hostname}#{Constants::Auth::USERINFO_ROUTE_PATH}",
        end_session_endpoint: "#{Settings.hostname}#{Constants::Auth::END_SESSION_ROUTE_PATH}",
        token_revocation_individual_endpoint: "#{Settings.hostname}#{Constants::Auth::TOKEN_REVOCATION_INDIVIDUAL_ROUTE_PATH}", # rubocop:disable Layout/LineLength
        revocation_endpoint: "#{Settings.hostname}#{Constants::Auth::REVOCATION_ROUTE_PATH}"
      }
    end

    def methods
      {
        code_challenge_methods_supported: Constants::Auth::CODE_CHALLENGE_METHOD
      }
    end

    def types
      {
        grant_types_supported: Constants::Auth::GRANT_TYPE,
        response_types_supported: Constants::Auth::RESPONSE_TYPES_SUPPORTED,
        scopes_supported: Constants::Auth::SCOPES_SUPPORTED,
        acr_values_supported: Constants::Auth::ACR_VALUES,
        subject_types_supported: Constants::Auth::SUBJECT_TYPES_SUPPORTED,
        claims_supported: Constants::Auth::CLAIMS_SUPPORTED,
        jwks_uri: Constants::Auth::JWKS_URI
      }
    end
  end
end
