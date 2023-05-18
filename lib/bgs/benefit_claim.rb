# frozen_string_literal: true

require_relative 'service'
require 'bgs/exceptions/service_exception'

module BGS
  class BenefitClaim
    include SentryLogging

    BENEFIT_CLAIM_PARAM_CONSTANTS = {
      benefit_claim_type: '1',
      payee: '00',
      disposition: 'M',
      section_unit_no: '555',
      folder_with_claim: 'N',
      pre_discharge_indicator: 'N'
    }.freeze

    attr_reader :vnp_benefit_claim,
                :veteran,
                :proc_id,
                :end_product_name,
                :end_product_code,
                :icn,
                :common_name,
                :ssn,
                :participant_id,
                :first_name,
                :last_name

    def initialize(vnp_benefit_claim:, # rubocop:disable Metrics/ParameterLists
                   veteran:,
                   proc_id:,
                   end_product_name:,
                   end_product_code:,
                   icn:,
                   common_name:,
                   ssn:,
                   participant_id:,
                   first_name:,
                   last_name:)
      @vnp_benefit_claim = vnp_benefit_claim
      @veteran = veteran
      @proc_id = proc_id
      @end_product_name = end_product_name
      @end_product_code = end_product_code
      @icn = icn
      @common_name = common_name
      @ssn = ssn
      @participant_id = participant_id
      @first_name = first_name
      @last_name = last_name
    end

    def create
      benefit_claim = bgs_service.insert_benefit_claim(benefit_claim_params:)

      {
        benefit_claim_id: benefit_claim.dig(:benefit_claim_record, :benefit_claim_id),
        claim_type_code: benefit_claim.dig(:benefit_claim_record, :claim_type_code),
        participant_claimant_id: benefit_claim.dig(:benefit_claim_record, :participant_claimant_id),
        program_type_code: benefit_claim.dig(:benefit_claim_record, :program_type_code),
        service_type_code: benefit_claim.dig(:benefit_claim_record, :service_type_code),
        status_type_code: benefit_claim.dig(:benefit_claim_record, :status_type_code)
      }
    rescue => e
      handle_error(e)
    end

    private

    # rubocop:disable Metrics/MethodLength
    def benefit_claim_params
      {
        file_number: veteran[:file_number],
        ssn:,
        ptcpnt_id_claimant: participant_id,
        end_product: veteran[:benefit_claim_type_end_product],
        first_name:,
        last_name:,
        address_line1: veteran[:address_line_one],
        address_line2: veteran[:address_line_two],
        address_line3: veteran[:address_line_three],
        city: veteran[:address_city],
        state: veteran[:address_state_code],
        postal_code: veteran[:address_zip_code],
        address_type: veteran[:address_type],
        mlty_postal_type_cd: veteran[:mlty_postal_type_cd],
        mlty_post_office_type_cd: veteran[:mlty_post_office_type_cd],
        foreign_mail_code: veteran[:foreign_mail_code],
        email_address: veteran[:email_address],
        country: veteran[:address_country],
        date_of_claim: Time.current.strftime('%m/%d/%Y'),
        end_product_name:,
        end_product_code:,
        soj: veteran[:regional_office_number]
      }.merge(BENEFIT_CLAIM_PARAM_CONSTANTS)
    end
    # rubocop:enable Metrics/MethodLength

    def handle_error(error)
      bgs_service.update_manual_proc(proc_id:)

      log_exception_to_sentry(error, { icn: }, { team: Constants::SENTRY_REPORTING_TEAM })
      raise BGS::ServiceException.new('BGS_686c_SERVICE_403', { source: self.class.to_s }, 403, error.message)
    end

    def bgs_service
      @bgs_service ||= BGS::Service.new(icn:, common_name:)
    end
  end
end
