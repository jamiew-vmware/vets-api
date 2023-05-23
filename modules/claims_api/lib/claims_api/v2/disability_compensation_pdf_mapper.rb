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
        symbolize_ser_info
        most_recent_ser_per
        array_of_remaining_serv_date_objects
        confinements
        national_guard
        service_info_other_names
        fed_activation

        @pdf_data
      end

      def symbolize_ser_info
        @pdf_data[:data][:attributes][:serviceInformation].merge!(
          @auto_claim['serviceInformation'].deep_symbolize_keys
        )

        @pdf_data
      end

      def most_recent_ser_per
        @pdf_data[:data][:attributes][:serviceInformation][:mostRecentActiveService] = {}
        most_recent_period = @pdf_data[:data][:attributes][:serviceInformation][:servicePeriods].max_by do |sp|
          sp[:activeDutyEndDate]
        end

        @pdf_data[:data][:attributes][:serviceInformation][:mostRecentActiveService][:startDate] =
          most_recent_period[:activeDutyBeginDate]
        @pdf_data[:data][:attributes][:serviceInformation][:mostRecentActiveService][:endDate] =
          most_recent_period[:activeDutyEndDate]
        @pdf_data[:data][:attributes][:serviceInformation][:placeOfLastOrAnticipatedSeparation] =
          most_recent_period[:separationLocationCode]
        @pdf_data[:data][:attributes][:serviceInformation][:branchOfService] = most_recent_period[:serviceBranch]
        @pdf_data[:data][:attributes][:serviceInformation][:serviceComponent] = most_recent_period[:serviceComponent]

        @pdf_data
      end

      def array_of_remaining_serv_date_objects
        arr = []
        @pdf_data[:data][:attributes][:serviceInformation][:servicePeriods].each do |sp|
          arr.push({ startDate: sp[:activeDutyBeginDate], endDate: sp[:activeDutyEndDate] })
        end
        sorted = arr.sort_by { |sp| sp[:activeDutyEndDate] }
        sorted.pop
        @pdf_data[:data][:attributes][:serviceInformation][:additionalPeriodsOfService] = sorted
        @pdf_data[:data][:attributes][:serviceInformation].delete(:servicePeriods)
        @pdf_data
      end

      def confinements
        si = {}
        @pdf_data[:data][:attributes][:serviceInformation][:confinements].map do |confinement|
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

        @pdf_data
      end

      def service_info_other_names
        other_names = @pdf_data[:data][:attributes][:serviceInformation][:alternateNames].present?
        names = @pdf_data[:data][:attributes][:serviceInformation][:alternateNames].join(', ')
        @pdf_data[:data][:attributes][:serviceInformation][:servedUnderAnotherName] = true if other_names
        @pdf_data[:data][:attributes][:serviceInformation][:alternateNames] = names
      end

      def fed_activation
        @pdf_data[:data][:attributes][:serviceInformation][:federalActivation] = {}
        ten = @pdf_data[:data][:attributes][:serviceInformation][:reservesNationalGuardService][:title10Activation]
        activation_date = ten[:title10ActivationDate]
        @pdf_data[:data][:attributes][:serviceInformation][:federalActivation][:activationDate] = activation_date

        anticipated_sep_date = ten[:anticipatedSeparationDate]
        @pdf_data[:data][:attributes][:serviceInformation][:federalActivation][:anticipatedSeparationDate] =
          anticipated_sep_date
        @pdf_data[:data][:attributes][:serviceInformation][:activatedOnFederalOrders] = true if activation_date
        @pdf_data[:data][:attributes][:serviceInformation][:reservesNationalGuardService].delete(:title10Activation)

        @pdf_data
      end
    end
  end
end
