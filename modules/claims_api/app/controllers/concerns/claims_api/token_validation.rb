# frozen_string_literal: true

require 'rest-client'

module ClaimsApi
  module TokenValidation
    extend ActiveSupport::Concern
    TOKEN_REGEX = /Bearer /

    included do
      def verify_access!
        verify_access_token!
      rescue
        render_unauthorized
      end

      # Determine if the current authenticated user is allowed access
      # raise if current authenticated user is neither the target veteran, nor target veteran representative
      def verify_access_token!
        @validated_token = validate_token!['data']
        attributes = @validated_token['attributes']
        @is_valid_ccg_flow ||= attributes['cid'] == attributes['sub']
        return if @is_valid_ccg_flow

        @current_user = user_from_validated_token(@validated_token)
      end

      def validate_token!
        token_validation_url = if Settings.claims_api.token_validation.url.nil?
                                 'https://sandbox-api.va.gov/internal/auth/v3/validation'
                               else
                                 Settings.claims_api.token_validation.url
                               end
        token_string = token_string_from_request
        root_url = request.base_url == 'https://api.va.gov' ? 'https://api.va.gov' : 'https://sandbox-api.va.gov'
        audience = "#{root_url}/services/claims"
        payload = { aud: audience }
        response = RestClient.post(token_validation_url,
                                   payload,
                                   { Authorization: "Bearer #{token_string}",
                                     apiKey: Settings.claims_api.token_validation.api_key })
        raise raise Common::Exceptions::TokenValidationError, 'Token validation error' if response.nil?

        @validated_token_payload = JSON.parse(response.body) if response.code == 200
      rescue => e
        raise ::Common::Exceptions::Unauthorized if e.to_s.include?('401')
      end
    end

    def token_string_from_request
      auth_request = request.authorization.to_s
      return unless auth_request[TOKEN_REGEX]

      auth_request.sub(TOKEN_REGEX, '').gsub(/^"|"$/, '')
    end

    def user_from_validated_token(validated_token)
      attributes = validated_token['attributes']
      uid = attributes['uid']
      act = attributes['act']
      icn = act['icn']
      claims_user = ClaimsUser.new(uid)
      claims_user.set_icn(icn) unless icn.nil?
      claims_user.first_name_last_name(act['first_name'], act['last_name']) unless act['last_name'].nil?
      claims_user
    end

    def permit_scopes(scopes, actions: [])
      return false unless @validated_token

      attributes = @validated_token['attributes']
      if (actions.empty? ||
        Array.wrap(actions).map(&:to_s).include?(action_name)) && !Array.wrap(scopes).intersect?(attributes['scp'])
        render_unauthorized
      end
    end
  end
end
