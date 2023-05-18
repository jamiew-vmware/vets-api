# frozen_string_literal: true

require_relative 'benefit_claim'
require_relative 'dependents'
require_relative 'service'
require_relative 'student_school'
require_relative 'vnp_benefit_claim'
require_relative 'vnp_relationships'
require_relative 'vnp_veteran'
require_relative 'dependent_higher_ed_attendance'
require_relative '../bid/awards/service'

module BGS
  class Form674
    include SentryLogging

    attr_reader :icn, :common_name, :participant_id, :ssn, :first_name, :middle_name, :last_name

    def initialize(icn:, ssn:, common_name:, first_name:, middle_name:, last_name:, participant_id:) # rubocop:disable Metrics/ParameterLists
      @icn = icn
      @ssn = ssn
      @common_name = common_name
      @first_name = first_name
      @middle_name = middle_name
      @last_name = last_name
      @participant_id = participant_id
      @end_product_name = '130 - Automated School Attendance 674'
      @end_product_code = '130SCHATTEBN'
    end

    def submit(payload) # rubocop:disable Metrics/MethodLength
      proc_id = create_proc_id_and_form
      veteran = VnpVeteran.new(proc_id:,
                               payload:,
                               icn:,
                               common_name:,
                               first_name:,
                               middle_name:,
                               last_name:,
                               participant_id:,
                               ssn:,
                               claim_type: '130SCHATTEBN').create

      process_relationships(proc_id, veteran, payload['dependents_application'])

      vnp_benefit_claim = VnpBenefitClaim.new(proc_id:, veteran:, icn:, common_name:)
      vnp_benefit_claim_record = vnp_benefit_claim.create

      set_claim_type('MANUAL_VAGOV') # we are TEMPORARILY always setting to MANUAL_VAGOV for 674

      # temporary logging to troubleshoot
      log_message_to_sentry("#{proc_id} - #{@end_product_code}", :warn, '', { team: 'vfs-ebenefits' })

      benefit_claim_record = BenefitClaim.new(
        vnp_benefit_claim: vnp_benefit_claim_record,
        veteran:,
        proc_id:,
        end_product_name: @end_product_name,
        end_product_code: @end_product_code,
        icn:,
        common_name:,
        ssn:,
        participant_id:,
        first_name:,
        last_name:
      ).create

      vnp_benefit_claim.update(benefit_claim_record, vnp_benefit_claim_record)

      # we only want to add a note if the claim is being set to MANUAL_VAGOV
      # but for now we are temporarily always setting to MANUAL_VAGOV for 674
      # when that changes, we need to surround this block of code in an IF statement
      note_text = 'Claim set to manual by VA.gov: This application needs manual review because a 674 was submitted.'
      bgs_service.create_note(claim_id: benefit_claim_record[:benefit_claim_id], note_text:, participant_id:)

      bgs_service.update_proc(proc_id:, proc_state: 'MANUAL_VAGOV')
    end

    private

    def process_relationships(proc_id, veteran, dependents_application)
      dependent = DependentHigherEdAttendance.new(proc_id:, dependents_application:, icn:, ssn:, common_name:).create

      VnpRelationships.new(
        proc_id:,
        veteran:,
        dependents: [dependent],
        step_children: [],
        icn:,
        common_name:
      ).create_all

      process_674(proc_id, dependent[:vnp_participant_id], dependents_application)
    end

    def process_674(proc_id, vnp_participant_id, dependents_application)
      StudentSchool.new(proc_id:, vnp_participant_id:, dependents_application:, icn:, common_name:).create
    end

    def create_proc_id_and_form
      vnp_response = bgs_service.create_proc(proc_state: 'MANUAL_VAGOV')
      bgs_service.create_proc_form(
        vnp_proc_id: vnp_response[:vnp_proc_id],
        form_type_code: '21-674'
      )

      vnp_response[:vnp_proc_id]
    end

    # the default claim type is 130SCHATTEBN (eBenefits School Attendance)
    # if we are setting the claim to be manually reviewed (we are temporarily doing this for all submissions)
    # and the Veteran is currently receiving pension benefits
    # set the claim type to 130SCAEBPMCR (PMC eBenefits School Attendance Reject)
    # else use 130SCHEBNREJ (eBenefits School Attendance Reject)
    def set_claim_type(proc_state)
      if proc_state == 'MANUAL_VAGOV'
        receiving_pension = false

        if Flipper.enabled?(:dependents_pension_check)
          pension_response = bid_service.get_awards_pension(participant_id:)
          receiving_pension = pension_response.body['awards_pension']['is_in_receipt_of_pension']
        end

        if receiving_pension
          @end_product_name = 'PMC eBenefits School Attendance Reject'
          @end_product_code = '130SCAEBPMCR'
        else
          @end_product_name = 'eBenefits School Attendance Reject'
          @end_product_code = '130SCHEBNREJ'
        end
      end
    end

    def bgs_service
      BGS::Service.new(icn:, common_name:)
    end

    def bid_service
      BID::Awards::Service.new
    end
  end
end
