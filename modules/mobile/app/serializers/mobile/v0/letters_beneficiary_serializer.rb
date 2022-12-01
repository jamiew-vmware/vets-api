# frozen_string_literal: true

require 'fast_jsonapi'

module Mobile
  module V0
    class LettersBeneficiarySerializer
      include FastJsonapi::ObjectSerializer

      set_type :LettersBeneficiaryResponses
      attributes :benefit_information, :military_service

      def initialize(user, resource, options = {})
        if Flipper.enabled?(:mobile_lighthouse_letters, user)
          super(resource, options)
        else
          resource.military_service.each do |service_episode|
            service_episode[:branch] = service_episode[:branch].titleize
          end
        end
        resource = LettersBeneficiaryStruct.new(user.uuid, resource.benefit_information, resource.military_service)
        super(resource, options)
      end
    end

    LettersBeneficiaryStruct = Struct.new(:id, :benefit_information, :military_service)
  end
end
