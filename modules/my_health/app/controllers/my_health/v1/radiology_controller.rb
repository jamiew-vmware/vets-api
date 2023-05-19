# frozen_string_literal: true

module MyHealth
  module V1
    class RadiologyController < MrController
      def index
        patient_id = params[:patient_id]
        resource = client.list_radiology(patient_id)
        raise Common::Exceptions::InternalServerError if resource.blank?

        render json: resource.to_json
      end

      def show
        radiology_id = params[:id].try(:to_i)
        resource = client.get_document_reference(radiology_id)
        raise Common::Exceptions::InternalServerError if resource.blank?

        render json: resource.to_json
      end
    end
  end
end
