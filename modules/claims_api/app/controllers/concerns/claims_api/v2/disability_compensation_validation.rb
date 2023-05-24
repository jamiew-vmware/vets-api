# frozen_string_literal: false

require 'brd/brd'

module ClaimsApi
  module V2
    module DisabilityCompensationValidation # rubocop:disable Metrics/ModuleLength:
      def validate_form_526_submission_values!
        # ensure 'claimDate', if provided, is a valid date not in the future
        validate_form_526_submission_claim_date!
        # ensure 'claimantCertification' is true
        validate_form_526_claimant_certification!
        # ensure mailing address country is valid
        validate_form_526_current_mailing_address_country!
        # ensure homeless information is valid
        validate_form_526_veteran_homelessness!
        # ensure new address is valid
        validate_form_526_change_of_address!
      end

      def validate_form_526_change_of_address!
        return if form_attributes['changeOfAddress'].blank?

        validate_form_526_change_of_address_beginning_date!
        validate_form_526_change_of_address_ending_date!
        validate_form_526_change_of_address_country!
      end

      def validate_form_526_change_of_address_beginning_date!
        change_of_address = form_attributes['changeOfAddress']
        date = change_of_address.dig('dates', 'beginningDate')
        return unless 'TEMPORARY'.casecmp?(change_of_address['typeOfAddressChange'])

        # If the date parse fails, then fall back to the InvalidFieldValue
        begin
          return if Date.parse(date) < Time.zone.now
        rescue
          raise ::Common::Exceptions::InvalidFieldValue.new('changeOfAddress.dates.beginningDate', date)
        end

        raise ::Common::Exceptions::InvalidFieldValue.new('changeOfAddress.dates.beginningDate', date)
      end

      def validate_form_526_change_of_address_ending_date!
        change_of_address = form_attributes['changeOfAddress']
        date = change_of_address.dig('dates', 'endingDate')
        return unless 'TEMPORARY'.casecmp?(change_of_address['typeOfAddressChange'])
        return if Date.parse(date) > Date.parse(change_of_address.dig('dates', 'beginningDate'))

        raise ::Common::Exceptions::InvalidFieldValue.new('changeOfAddress.dates.endingDate', date)
      end

      def validate_form_526_change_of_address_country!
        change_of_address = form_attributes['changeOfAddress']
        return if valid_countries.include?(change_of_address['country'])

        raise ::Common::Exceptions::InvalidFieldValue.new('changeOfAddress.country', change_of_address['country'])
      end

      def validate_form_526_submission_claim_date!
        return if form_attributes['claimDate'].blank?
        # EVSS runs in the Central US Time Zone.
        # So 'claim_date' needs to be <= current day according to the Central US Time Zone.
        return if Date.parse(form_attributes['claimDate']) <= Time.find_zone!('Central Time (US & Canada)').today

        raise ::Common::Exceptions::InvalidFieldValue.new('claimDate', form_attributes['claimDate'])
      end

      def validate_form_526_claimant_certification!
        return unless form_attributes['claimantCertification'] == false

        raise ::Common::Exceptions::InvalidFieldValue.new('claimantCertification',
                                                          form_attributes['claimantCertification'])
      end

      def validate_form_526_current_mailing_address_country!
        mailing_address = form_attributes.dig('veteranIdentification', 'mailingAddress')
        return if valid_countries.include?(mailing_address['country'])

        raise ::Common::Exceptions::InvalidFieldValue.new('country', mailing_address['country'])
      end

      def valid_countries
        @valid_countries ||= ClaimsApi::BRD.new(request).countries
      end

      def validate_form_526_veteran_homelessness!
        handle_empty_other_description

        if too_many_homelessness_attributes_provided?
          raise ::Common::Exceptions::UnprocessableEntity.new(
            detail: "Must define only one of 'homeless.currentlyHomeless' or " \
                    "'homeless.riskOfBecomingHomeless'"
          )
        end

        if unnecessary_homelessness_point_of_contact_provided?
          raise ::Common::Exceptions::UnprocessableEntity.new(
            detail: "If 'homeless.pointOfContact' is defined, then one of " \
                    "'homeless.currentlyHomeless' or 'homeless.riskOfBecomingHomeless' is required"
          )
        end

        if missing_point_of_contact?
          raise ::Common::Exceptions::UnprocessableEntity.new(
            detail: "If one of 'homeless.currentlyHomeless' or 'homeless.riskOfBecomingHomeless' is " \
                    "defined, then 'homeless.pointOfContact' is required"
          )
        end
      end

      def get_homelessness_attributes
        currently_homeless_attr = form_attributes.dig('homeless', 'currentlyHomeless')
        homelessness_risk_attr = form_attributes.dig('homeless', 'riskOfBecomingHomeless')
        [currently_homeless_attr, homelessness_risk_attr]
      end

      def handle_empty_other_description
        currently_homeless_attr, homelessness_risk_attr = get_homelessness_attributes

        # Set otherDescription to ' ' to bypass docker container validation
        if currently_homeless_attr.present?
          homeless_situation_options = currently_homeless_attr['homelessSituationOptions']
          other_description = currently_homeless_attr['otherDescription']
          if homeless_situation_options == 'OTHER' && other_description.blank?
            form_attributes['homeless']['currentlyHomeless']['otherDescription'] = ' '
          end
        elsif homelessness_risk_attr.present?
          living_situation_options = homelessness_risk_attr['livingSituationOptions']
          other_description = homelessness_risk_attr['otherDescription']
          if living_situation_options == 'other' && other_description.blank?
            form_attributes['homeless']['riskOfBecomingHomeless']['otherDescription'] = ' '
          end
        end
      end

      def too_many_homelessness_attributes_provided?
        currently_homeless_attr, homelessness_risk_attr = get_homelessness_attributes
        # EVSS does not allow both attributes to be provided at the same time
        currently_homeless_attr.present? && homelessness_risk_attr.present?
      end

      def unnecessary_homelessness_point_of_contact_provided?
        currently_homeless_attr, homelessness_risk_attr = get_homelessness_attributes
        homelessness_poc_attr = form_attributes.dig('homeless', 'pointOfContact')

        # EVSS does not allow passing a 'pointOfContact' if neither homelessness attribute is provided
        currently_homeless_attr.blank? && homelessness_risk_attr.blank? && homelessness_poc_attr.present?
      end

      def missing_point_of_contact?
        homelessness_poc_attr = form_attributes.dig('homeless', 'pointOfContact')
        currently_homeless_attr, homelessness_risk_attr = get_homelessness_attributes

        # 'pointOfContact' is required when either currentlyHomeless or homelessnessRisk is provided
        homelessness_poc_attr.blank? && (currently_homeless_attr.present? || homelessness_risk_attr.present?)
      end
    end
  end
end
