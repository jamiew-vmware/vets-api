# frozen_string_literal: true

require 'evss/disability_compensation_auth_headers'
require 'evss/auth_headers'
require 'token_validation/v2/client'
require 'claims_api/error/error_handler'
require 'claims_api/claim_logger'
require 'bgs_service/local_bgs'

module ClaimsApi
  module V2
    class ApplicationController < ::ApplicationController
      include ClaimsApi::Error::ErrorHandler
      include ClaimsApi::TokenValidation
      include ClaimsApi::CcgTokenValidation
      include ClaimsApi::TargetVeteran
      skip_before_action :verify_authenticity_token
      skip_after_action :set_csrf_header
      before_action :authenticate

      def schema
        render json: { data: [ClaimsApi::FormSchemas.new(schema_version: 'v2').schemas[self.class::FORM_NUMBER]] }
      end

      protected

      def auth_headers
        evss_headers = EVSS::DisabilityCompensationAuthHeaders
                       .new(target_veteran)
                       .add_headers(
                         EVSS::AuthHeaders.new(target_veteran).to_h
                       )
        evss_headers['va_eauth_pnid'] = target_veteran.mpi.profile.ssn

        if request.headers['Mock-Override'] &&
           Settings.claims_api.disability_claims_mock_override
          evss_headers['Mock-Override'] = request.headers['Mock-Override']
          Rails.logger.info('ClaimsApi: Mock Override Engaged')
        end

        evss_headers
      end

      #
      # For validating the incoming request body
      # @param validator_class [any] Class implementing ActiveModel::Validations
      #
      def validate_request!(validator_class)
        validator = validator_class.validator(params)
        return if validator.valid?

        raise ::Common::Exceptions::ValidationErrorsBadRequest, validator
      end

      #
      # Determine if the current authenticated user is the Veteran being acted on
      #
      # @return [boolean] True if the current user is the Veteran being acted on, false otherwise
      def user_is_target_veteran?
        return false if params[:veteranId].blank?
        return false if @current_user.icn.blank?
        return false if target_veteran&.mpi&.icn.blank?
        return false unless params[:veteranId] == target_veteran.mpi.icn

        @current_user.icn == target_veteran.mpi.icn
      end

      #
      # Determine if the current authenticated user is the target veteran's representative
      #
      # @return [boolean] True if the current authenticated user is the target veteran's representative
      def user_represents_veteran?
        reps = ::Veteran::Service::Representative.all_for_user(
          first_name: @current_user.first_name,
          last_name: @current_user.last_name
        )

        return false if reps.blank?
        return false if reps.count > 1

        rep = reps.first
        veteran_poa_code = ::Veteran::User.new(target_veteran)&.power_of_attorney&.code

        return false if veteran_poa_code.blank?

        rep.poa_codes.include?(veteran_poa_code)
      end

      private

      def bgs_service
        BGS::Services.new(external_uid: target_veteran.participant_id,
                          external_key: target_veteran.participant_id)
      end

      def local_bgs_service
        @local_bgs_service ||= ClaimsApi::LocalBGS.new(
          external_uid: target_veteran.participant_id,
          external_key: target_veteran.participant_id
        )
      end

      def build_target_veteran(veteran_id:, loa:) # rubocop:disable Metrics/MethodLength
        target_veteran ||= ClaimsApi::Veteran.new(
          mhv_icn: veteran_id,
          loa:
        )
        # populate missing veteran attributes with their mpi record
        found_record = target_veteran.mpi_record?(user_key: veteran_id)

        unless found_record
          raise ::Common::Exceptions::ResourceNotFound.new(detail:
            "Unable to locate Veteran's ID/ICN in Master Person Index (MPI). " \
            'Please submit an issue at ask.va.gov or call 1-800-MyVA411 (800-698-2411) for assistance.')
        end

        mpi_profile = target_veteran&.mpi&.mvi_response&.profile || {}

        if mpi_profile[:participant_id].blank?
          raise ::Common::Exceptions::UnprocessableEntity.new(detail:
            "Unable to locate Veteran's Participant ID in Master Person Index (MPI). " \
            'Please submit an issue at ask.va.gov or call 1-800-MyVA411 (800-698-2411) for assistance.')
        end

        target_veteran[:first_name] = mpi_profile[:given_names]&.first
        if target_veteran[:first_name].nil?
          raise ::Common::Exceptions::UnprocessableEntity.new(detail: 'Missing first name')
        end

        target_veteran[:last_name] = mpi_profile[:family_name]
        target_veteran[:edipi] = mpi_profile[:edipi]
        target_veteran[:uuid] = mpi_profile[:ssn]
        target_veteran[:ssn] = mpi_profile[:ssn]
        target_veteran[:participant_id] = mpi_profile[:participant_id]
        target_veteran[:last_signed_in] = Time.now.utc
        target_veteran[:va_profile] = ClaimsApi::Veteran.build_profile(mpi_profile.birth_date)
        target_veteran
      end
    end
  end
end
