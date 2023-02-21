# frozen_string_literal: true

require 'sign_in/logingov/service'
require 'sign_in/idme/service'
require 'sign_in/logger'

module V0
  class MockAuthController < SignIn::ApplicationController
    skip_before_action :authenticate
    before_action :set_user_attributes
    before_action :set_state

    def authenticate
      user_attributes = JSON.parse(params[:user_attributes]).deep_symbolize_keys
      verified_icn = SignIn::AttributeValidator.new(user_attributes: user_attributes).perform
      user_code_map = SignIn::UserCreator.new(user_attributes: user_attributes,
                                              state_payload: @state_payload,
                                              verified_icn: verified_icn,
                                              request_ip: request.ip).perform
      redirect_to SignIn::LoginRedirectUrlGenerator.new(user_code_map: user_code_map).perform
    end

    private

    def set_user_attributes
      @user_attributes = JSON.parse(params[:user_attributes]).deep_symbolize_keys
    end

    def set_state
      @state_payload = SignIn::StatePayloadJwtDecoder.new(state_payload_jwt: params[:state]).perform
      SignIn::StatePayloadVerifier.new(state_payload: @state_payload).perform
    end
  end
end
