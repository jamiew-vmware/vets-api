# frozen_string_literal: true

module SignIn
  module WellKnown
    class Service
      def openid_data
        {
          issuer: Settings.logingov.oauth_url,
          authorization_endpoint: "#{Settings.logingov.oauth_url}/oauth2/authorize",
          token_endpoint: "#{Settings.logingov.oauth_url}/oauth2/token",
          token_refresh_endpoint: "#{Settings.logingov.oauth_url}/oauth2/refresh",
          introspection_endpoint: "#{Settings.logingov.oauth_url}/oauth2/introspect",
          end_session_endpoint: "#{Settings.logingov.oauth_url}/oauth2/logout",
          token_revocation_individual_endpoint: "#{Settings.logingov.oauth_url}/oauth2/revoke",
          revocation_endpoint: "#{Settings.logingov.oauth_url}/oauth2/revoke_all",
          scopes_supported: %w[openid profile email address phone offline_access],
          response_types_supported: %w[code token code token],
          response_modes_supported: %w[query fragment form_post okta_post_message],
          grant_types_supported: %w[authorization_code implicit refresh_token password client_credentials],
          token_endpoint_auth_methods_supported: %w[client_secret_basic client_secret_post client_secret_jwt private_key_jwt none], # rubocop:disable Layout/LineLength
          revocation_endpoint_auth_methods_supported: %w[client_secret_basic client_secret_post client_secret_jwt private_key_jwt none], # rubocop:disable Layout/LineLength
          introspection_endpoint_auth_methods_supported: %w[client_secret_basic client_secret_post client_secret_jwt private_key_jwt none], # rubocop:disable Layout/LineLength
          code_challenge_methods_supported: %w[plain S256]
        }
      end
    end
  end
end
