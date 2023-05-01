# frozen_string_literal: true

module SignIn
  class WellKnown
    SCOPES_SUPPORTED = 'openid profile email address phone offline_access'
    RESPONSE_TYPES_SUPPORTED = 'code token code token'
    RESPONSE_MODES_SUPPORTED = 'query fragment form_post okta_post_message'
    GRANT_TYPES_SUPPORTED    = 'authorization_code implicit refresh_token password client_credentials'
    TOKEN_ENDPOINT_AUTH_METHODS_SUPPORTED = 'client_secret_basic client_secret_post client_secret_jwt private_key_jwt none' # rubocop:disable Layout/LineLength
    REVOCATION_ENDPOINT_AUTH_METHODS_SUPPORTED = 'client_secret_basic client_secret_post client_secret_jwt private_key_jwt none' # rubocop:disable Layout/LineLength
    INTROSPECTION_ENDPOINT_AUTH_METHODS_SUPPORTED = 'client_secret_basic client_secret_post client_secret_jwt private_key_jwt none' # rubocop:disable Layout/LineLength
    def openid_data
      {
        issuer: Settings.hostname,
        authorization_endpoint: "#{Settings.hostname}#{Constants::Auth::AUTHORIZATION_ENDPOINT}",
        token_endpoint: "#{Settings.hostname}#{Constants::Auth::TOKEN_ENDPOINT}",
        token_refresh_endpoint: "#{Settings.hostname}#{Constants::Auth::REFRESH_ROUTE_PATH}",
        introspection_endpoint: "#{Settings.hostname}#{Constants::Auth::INTROSPECTION_ENDPOINT}",
        end_session_endpoint: "#{Settings.hostname}#{Constants::Auth::END_SESSION_ENDPOINT}",
        token_revocation_individual_endpoint: "#{Settings.hostname}#{Constants::Auth::TOKEN_REVOCATION_INDIVIDUAL_ENDPOINT}", # rubocop:disable Layout/LineLength
        revocation_endpoint: "#{Settings.hostname}#{Constants::Auth::REVOCATION_ENDPOINT}",
        scopes_supported: SCOPES_SUPPORTED,
        response_types_supported: RESPONSE_TYPES_SUPPORTED,
        response_modes_supported: RESPONSE_MODES_SUPPORTED,
        grant_types_supported: GRANT_TYPES_SUPPORTED,
        token_endpoint_auth_methods_supported: TOKEN_ENDPOINT_AUTH_METHODS_SUPPORTED,
        revocation_endpoint_auth_methods_supported: REVOCATION_ENDPOINT_AUTH_METHODS_SUPPORTED,
        introspection_endpoint_auth_methods_supported: INTROSPECTION_ENDPOINT_AUTH_METHODS_SUPPORTED,
        code_challenge_methods_supported: Constants::Auth::CODE_CHALLENGE_METHOD
      }
    end
  end
end
