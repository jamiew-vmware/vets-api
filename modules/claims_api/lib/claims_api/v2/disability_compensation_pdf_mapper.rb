# frozen_string_literal: true

module ClaimsApi
  module V2
    class DisabilityCompensationPdfMapper
      def initialize(auto_claim, pdf_data)
        @auto_claim = auto_claim
        @pdf_data = pdf_data
      end

      def map_claim
        claim_attributes
        toxic_exposure_attributes
        homeless_attributes
        chg_addr_attributes
        veteran_info
        service_info

        @pdf_data
      end

      def claim_attributes
        @pdf_data[:data][:attributes] = @auto_claim.deep_symbolize_keys
        claim_date
        veteran_info

        @pdf_data
      end

      def claim_date
        @pdf_data[:data][:attributes].merge!(claimCertificationAndSignature: { dateSigned: @auto_claim['claimDate'] })
        @pdf_data[:data][:attributes].delete(:claimDate)

        @pdf_data
      end

      def homeless_attributes
        @pdf_data[:data][:attributes][:homelessInformation] = @auto_claim['homeless'].deep_symbolize_keys
        @pdf_data[:data][:attributes].delete(:homeless)

        homeless_at_risk_or_currently

        @pdf_data
      end

      def homeless_at_risk_or_currently
        at_risk = @auto_claim&.dig('homeless', 'riskOfBecomingHomeless', 'otherDescription').present?
        currently = @auto_claim&.dig('homeless', 'pointOfContact').present?

        if currently && !at_risk
          @pdf_data[:data][:attributes][:homelessInformation].merge!(areYouCurrentlyHomeless: true)
        else
          @pdf_data[:data][:attributes][:homelessInformation].merge!(areYouAtRiskOfBecomingHomeless: true)
        end

        @pdf_data
      end

      def chg_addr_attributes
        @pdf_data[:data][:attributes][:changeOfAddress] =
          @auto_claim['changeOfAddress'].deep_symbolize_keys

        chg_addr_zip

        @pdf_data
      end

      def chg_addr_zip
        zip = @auto_claim['changeOfAddress']['zipFirstFive'] +
              @auto_claim['changeOfAddress']['zipLastFour']
        @pdf_data[:data][:attributes][:changeOfAddress].merge!(zip:)
      end

      def toxic_exposure_attributes
        @pdf_data[:data][:attributes].merge!(
          exposureInformation: { toxicExposure: @auto_claim['toxicExposure'].deep_symbolize_keys }
        )
        @pdf_data[:data][:attributes].delete(:toxicExposure)

        conditions_related_to_exposure?
      end

      def veteran_info
        @pdf_data[:data][:attributes].merge!(
          identificationInformation: @auto_claim['veteranIdentification'].deep_symbolize_keys
        )
        zip

        @pdf_data
      end

      def zip
        zip = @auto_claim['veteranIdentification']['mailingAddress']['zipFirstFive'] +
              @auto_claim['veteranIdentification']['mailingAddress']['zipLastFour']
        @pdf_data[:data][:attributes][:identificationInformation][:mailingAddress].merge!(zip:)
      end

      def conditions_related_to_exposure?
        # If any disability is included in the request with 'isRelatedToToxicExposure' set to true,
        # set exposureInformation.hasConditionsRelatedToToxicExposures to true.
        # This will check 'YES' for box 15A.
        # TODO: for disability mapping ticket
      end

      def service_info
        service_periods
        confinements
        national_guard

        @pdf_data
      end

      def service_periods
        @pdf_data[:data][:attributes][:serviceInformation].merge!(
          @auto_claim["serviceInformation"].deep_symbolize_keys
        )
        # what of there are more than one service period?
        details = @pdf_data[:data][:attributes][:serviceInformation][:servicePeriods].map do |ser_per|
          act_start = ser_per[:activeDutyBeginDate]
          act_end = ser_per[:activeDutyEndDate]
          # TODO: get location name from code
          location = ser_per[:separationLocationCode]
          branch = ser_per[:serviceBranch]
          component = ser_per[:serviceComponent]

          @pdf_data[:data][:attributes][:serviceInformation][:mostRecentActiveService] = {}
          @pdf_data[:data][:attributes][:serviceInformation][:additionalPeriodsOfService] = {}
          
          @pdf_data[:data][:attributes][:serviceInformation][:mostRecentActiveService][:startDate] = act_start
          @pdf_data[:data][:attributes][:serviceInformation][:additionalPeriodsOfService][:startDate] = act_start
          @pdf_data[:data][:attributes][:serviceInformation][:mostRecentActiveService][:endDate] = act_end
          @pdf_data[:data][:attributes][:serviceInformation][:additionalPeriodsOfService][:endDate] = act_end
          @pdf_data[:data][:attributes][:serviceInformation][:placeOfLastOrAnticipatedSeparation] = location
          @pdf_data[:data][:attributes][:serviceInformation][:branchOfService] = branch
          @pdf_data[:data][:attributes][:serviceInformation][:serviceComponent] = component
          @pdf_data[:data][:attributes][:serviceInformation]
        end
        
        @pdf_data
      end
      
      def confinements
        si = {}
        addtl_service_info = @pdf_data[:data][:attributes][:serviceInformation][:confinements].map do |confinement|
          start = confinement[:confinement][:approximateBeginDate]
          end_date = confinement[:confinement][:approximateEndDate]
          si[:prisonerOfWarConfinement] = { confinementDates: {} }
          si[:prisonerOfWarConfinement][:confinementDates][:startDate] = start
          si[:prisonerOfWarConfinement][:confinementDates][:endDate] = end_date
          si[:confinedAsPrisonerOfWar] = true if start
          si
        end
        @pdf_data[:data][:attributes][:serviceInformation].merge!(si)
        
        @pdf_data
      end

      def national_guard
        si = {}
        reserves = @pdf_data[:data][:attributes][:serviceInformation][:reservesNationalGuardService]
        si[:servedInReservesOrNationalGuard] = true if reserves[:obligationTermsOfService][:startDate]
        @pdf_data[:data][:attributes][:serviceInformation].merge!(si)

      end
    end
  end
end
