# frozen_string_literal: true

require 'lighthouse/benefits_claims/service_mobile'
require 'lighthouse/benefits_claims/configuration_mobile'

require 'lighthouse/benefits_claims/service'

module V0
  class BenefitsClaimsController < ApplicationController
    before_action { authorize :lighthouse, :access? }

    def index
      claims = service.get_claims

      render json: claims
    end

    def show
      claim = service.get_claim(params[:id])

      render json: claim
    end

    private

    def service
      @service ||= BenefitsClaims::MobileService.new(@current_user.icn)
    end
  end
end
