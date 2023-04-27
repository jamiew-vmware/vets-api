# frozen_string_literal: true

require 'json_schema/json_api_missing_attribute'
require 'claims_api/form_schemas'
require 'json'

module ClaimsApi
  module V2
    module Veterans
      class Base < ClaimsApi::V2::ApplicationController
        FORM_NUMBER = '526'

        private

        def validate_json_schema
          validator = ClaimsApi::FormSchemas.new(schema_version: 'v2')
          validator.validate!(self.class::FORM_NUMBER, form_attributes)
        end

        def form_attributes
          @json_body.dig('data', 'attributes') || {}
        end
      end
    end
  end
end
