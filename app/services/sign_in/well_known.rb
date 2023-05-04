# frozen_string_literal: true

module SignIn
  module WellKnown
    class Generator
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
          token_refresh_endpoint: "#{Settings.hostname}#{Constants::Auth::REFRESH_ROUTE_PATH}",
          introspection_endpoint: "#{Settings.hostname}#{Constants::Auth::INTROSPECTION_ROUTE_PATH}",
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
          grant_types_supported: Constants::Auth::GRANT_TYPE
        }
      end
    end
  end
end
