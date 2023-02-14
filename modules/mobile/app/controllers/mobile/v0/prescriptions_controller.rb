# frozen_string_literal: true

require 'rx/client'

module Mobile
  module V0
    class PrescriptionsController < ApplicationController
      before_action { authorize :mhv_prescriptions, :access? }

      def index
        resource = client.get_history_rxs
        results, error = ListFilter.matches(resource.data, params[:filter])

        # this would normally not be necessary but we're using the collection sorting
        resource.data = results
        resource = resource.sort(params[:sort])

        page_resource, page_meta_data = paginate(resource.data, error.message)
        render json: Mobile::V0::PrescriptionsSerializer.new(page_resource, page_meta_data)
      end

      def refill
        resource = client.post_refill_rxs(ids)
        render json: Mobile::V0::PrescriptionsRefillsSerializer.new(@current_user.uuid, resource.body)
      end

      def tracking
        resource = client.get_tracking_history_rx(params[:id])
        render json: Mobile::V0::PrescriptionTrackingSerializer.new(resource.data)
      end

      private

      def client
        @client ||= Rx::Client.new(session: { user_id: @current_user.mhv_correlation_id }).authenticate
      end

      def pagination_params
        @pagination_params ||= {
          page_number: params.dig(:page, :number),
          page_size: params.dig(:page, :size)
        }
      end

      def paginate(records, errors)
        Mobile::PaginationHelper.paginate(list: records, validated_params: pagination_params, errors: errors)
      end

      def ids
        ids = params.require(:ids)
        raise Common::Exceptions::InvalidFieldValue.new('ids', ids) unless ids.is_a? Array

        ids.map(&:to_i)
      end
    end
  end
end
