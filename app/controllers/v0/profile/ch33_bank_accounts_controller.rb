# frozen_string_literal: true

require 'bgs/service'

module V0
  module Profile
    class Ch33BankAccountsController < ApplicationController
      before_action { authorize :ch33_dd, :access? }

      def index
        render_find_ch33_dd_eft
      end

      def update
        res = service.update_ch33_dd_eft(
          routing_number: params[:financial_institution_routing_number],
          account_number: params[:account_number],
          checking_account: params[:account_type] == 'Checking',
          ssn: current_user.ssn
        ).body

        unless res[:update_ch33_dd_eft_response][:return][:return_code] == 'S'
          return render(json: res, status: :bad_request)
        end

        VANotifyDdEmailJob.send_to_emails(current_user.all_emails, :ch33)

        Rails.logger.warn('Ch33BankAccountsController#update request completed', sso_logging_info)

        render_find_ch33_dd_eft
      end

      private

      def render_find_ch33_dd_eft
        get_ch33_dd_eft_info = service.get_ch33_dd_eft_info(ssn: current_user.ssn)
        render(
          json: get_ch33_dd_eft_info,
          serializer: Ch33BankAccountSerializer
        )
      end

      def service
        BGS::Service.new(icn: current_user.icn, common_name: current_user.common_name)
      end
    end
  end
end
