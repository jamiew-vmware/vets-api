# frozen_string_literal: true

require 'lighthouse/benefits_claims/service'

module V0
  class BenefitsClaimsController < ApplicationController
    def index
      claims = service.get_claims(settings.access_token.client_id, settings.access_token.rsa_key)

      render json: claims
    end

    def show
      claim = service.get_claim(params[:id], settings.access_token.client_id, settings.access_token.rsa_key)

      render json: claim
    end

    private

    # TODO-BDEX: Double check if this has any cascading implications
    def service
      @service ||= BenefitsClaims::Service.new(@current_user.icn, @current_user.ssn)
    end

    def settings
      @settings ||= Settings.lighthouse.benefits_claims
    end

    def settings
      @settings ||= Settings.lighthouse.benefits_claims
    end
  end
end
