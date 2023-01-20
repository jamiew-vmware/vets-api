# frozen_string_literal: true

require 'rx/client'

module Mobile
  module V0
    class PrescriptionsController < ApplicationController
      before_action { authorize :mhv_prescriptions, :access? }

      def index
        resource = client.get_history_rxs
        results, errors = ListFilter.matches(resource.data, params[:filter])
        # this would normally not be necessary but we're using the collection sorting
        resource.data = results
        resource = resource.sort(params[:sort])
        page_resource, page_meta_data = paginate(resource.data, errors)

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
        @pagination_params ||= Mobile::V0::Contracts::Prescriptions.new.call(
          page_number: params.dig(:page, :number),
          page_size: params.dig(:page, :size),
          filter: params[:filter].present? ? filter_params.to_h : nil,
          sort: params[:sort]
        )
      end

      def paginate(records, errors)
        url = request.base_url + request.path
        Mobile::PaginationHelper.paginate(list: records, validated_params: pagination_params, url: url, errors: errors)
      end

      def filter_params
        @filter_params ||= begin
          valid_filter_params = params.require(:filter).permit(Prescription.filterable_attributes)
          raise Common::Exceptions::FilterNotAllowed, params[:filter] if valid_filter_params.empty?

          valid_filter_params
        end
      end

      def ids
        ids = params.require(:ids)
        raise Common::Exceptions::InvalidFieldValue.new('ids', ids) unless ids.is_a? Array

        ids.map(&:to_i)
      end
    end
  end
end
