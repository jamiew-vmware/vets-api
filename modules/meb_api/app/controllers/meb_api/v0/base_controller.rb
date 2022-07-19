# frozen_string_literal: true

require 'dgi/claimant/service'
require 'dgi/letters/service'
require 'dgi/status/service'

module MebApi
  module V0
    class BaseController < ::ApplicationController
      protected

      def check_flipper
        routing_error unless Flipper.enabled?(:show_meb_mock_endpoints)
      end

      def check_toe_flipper
        routing_error unless Flipper.enabled?(:show_updated_toe_app)
      end

      private

      def claim_status_service
        MebApi::DGI::Status::Service.new(@current_user)
      end

      def claim_letters_service
        MebApi::DGI::Letters::Service.new(@current_user)
      end

      def claimant_service
        MebApi::DGI::Claimant::Service.new(@current_user)
      end
    end
  end
end
