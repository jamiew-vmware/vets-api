# frozen_string_literal: false

require 'brd/brd'

module ClaimsApi
  module V2
    module DisabilityCompensationValidation
      def validate_form_526_submission_values!
        # ensure 'claimDate', if provided, is a valid date not in the future
        validate_form_526_submission_claim_date!
        # ensure 'claimantCertification' is true
        validate_form_526_claimant_certification!
        # ensure mailing address country is valid
        validate_form_526_current_mailing_address_country!
        # ensure disabilities are valid
        validate_form_526_disabilities!
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

      def validate_form_526_disabilities!
        validate_form_526_disability_classification_code!
        validate_form_526_disability_approximate_begin_date!
        validate_form_526_disability_secondary_disabilities!
      end

      def validate_form_526_disability_classification_code!
        return if (form_attributes['disabilities'].pluck('classificationCode') - [nil]).blank?

        form_attributes['disabilities'].each do |disability|
          next if disability['classificationCode'].blank?
          if brd_classification_ids.include?(disability['classificationCode'].to_i)
            validate_form_526_disability_name!(disability['classificationCode'].to_i, disability['name'])
          else 
            raise ::Common::Exceptions::UnprocessableEntity.new(
              detail: "'disabilities.classificationCode' must match the associated id " \
                      "value returned from the /disabilities endpoint of the Benefits " \
                      "Reference Data API"
            )
          end
        end
      end

      def validate_form_526_disability_name!(classification_code, disability_name)
        if disability_name.blank?
          raise ::Common::Exceptions::InvalidFieldValue.new('disabilities.name',
                                                            disability['name'])
        end
        reference_disability = brd_disabilities.find {|x| x[:id] == classification_code}
        return if reference_disability[:name] == disability_name
        raise ::Common::Exceptions::UnprocessableEntity.new(
          detail: "'disabilities.name' must match the name value associated " \
                  "with 'disabilities.classificationCode' as returned from the " \
                  "/disabilities endpoint of the Benefits Reference Data API"
        )
      end
  
      def brd_classification_ids
        return @brd_classification_ids if @brd_classification_ids.present?

        brd_disabilities_arry = ClaimsApi::BRD.new(request).disabilities
        @brd_classification_ids = brd_disabilities_arry.pluck(:id)
      end

      def brd_disabilities
        return @brd_disabilities if @brd_disabilities.present?

        @brd_disabilities = ClaimsApi::BRD.new(request).disabilities
      end

      def validate_form_526_disability_approximate_begin_date!
        disabilities = form_attributes['disabilities']
        return if disabilities.blank?
  
        disabilities.each do |disability|
          approx_begin_date = disability['approximateBeginDate']
          next if approx_begin_date.blank?
  
          next if Date.parse(approx_begin_date) < Time.zone.today
  
          raise ::Common::Exceptions::InvalidFieldValue.new('disability.approximateBeginDate', approx_begin_date)
        end
      end

      def validate_form_526_disability_secondary_disabilities!
        form_attributes['disabilities'].each do |disability|
          validate_form_526_disability_secondary_disability_disability_action_type!(disability)
          next if disability['secondaryDisabilities'].blank?
  
          disability['secondaryDisabilities'].each do |secondary_disability|
            if secondary_disability['classificationCode'].present?
              validate_form_526_disability_secondary_disability_classification_code!(secondary_disability)
              validate_form_526_disability_secondary_disability_classification_code_matches_name!(
                secondary_disability
              )
            else
              validate_form_526_disability_secondary_disability_name!(secondary_disability)
            end
  
            if secondary_disability['approximateBeginDate'].present?
              validate_form_526_disability_secondary_disability_approximate_begin_date!(secondary_disability)
            end
          end
        end
      end

      def validate_form_526_disability_secondary_disability_disability_action_type!(disability)
        return unless disability['disabilityActionType'] == 'NONE' && disability['secondaryDisabilities'].blank?
  
        raise ::Common::Exceptions::InvalidFieldValue.new('disabilities.secondaryDisabilities',
                                                          disability['secondaryDisabilities'])
      end
  
      def validate_form_526_disability_secondary_disability_classification_code!(secondary_disability)
        return if brd_classification_ids.include?(secondary_disability['classificationCode'].to_i)
  
        raise ::Common::Exceptions::UnprocessableEntity.new(
          detail: "'disabilities.secondaryDisabilities.classificationCode' must match the associated id " \
                  "value returned from the /disabilities endpoint of the Benefits " \
                  "Reference Data API"
        )
      end
  
      def validate_form_526_disability_secondary_disability_classification_code_matches_name!(secondary_disability)
        if secondary_disability['name'].blank?
          raise ::Common::Exceptions::InvalidFieldValue.new('disabilities.secondaryDisabilities.name',
            secondary_disability['name'])
        end
        reference_disability = brd_disabilities.find {|x| x[:id] == secondary_disability['classificationCode'].to_i}
        return if reference_disability[:name] == secondary_disability['name']
        raise ::Common::Exceptions::UnprocessableEntity.new(
          detail: "'disabilities.secondaryDisabilities.name' must match the name value associated " \
                  "with 'disabilities.secondaryDisabilities.classificationCode' as returned from the " \
                  "/disabilities endpoint of the Benefits Reference Data API"
        )
      end
  
      def validate_form_526_disability_secondary_disability_name!(secondary_disability)
        return if %r{([a-zA-Z0-9\-'.,/()]([a-zA-Z0-9\-',. ])?)+$}.match?(secondary_disability['name']) &&
                  secondary_disability['name'].length <= 255
  
        raise ::Common::Exceptions::InvalidFieldValue.new(
          'disabilities.secondaryDisabilities.name',
          secondary_disability['name']
        )
      end
  
      def validate_form_526_disability_secondary_disability_approximate_begin_date!(secondary_disability)
        return if Date.parse(secondary_disability['approximateBeginDate']) < Time.zone.today
  
        raise ::Common::Exceptions::InvalidFieldValue.new(
          'disabilities.secondaryDisabilities.approximateBeginDate',
          secondary_disability['approximateBeginDate']
        )
      rescue ArgumentError
        raise ::Common::Exceptions::InvalidFieldValue.new(
          'disabilities.secondaryDisabilities.approximateBeginDate',
          secondary_disability['approximateBeginDate']
        )
      end
    end
  end
end
