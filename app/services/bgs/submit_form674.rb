# frozen_string_literal: true

require 'bgs/form674'

module BGS
  class SubmitForm674
    class Invalid674Claim < StandardError; end
    FORM_ID = '686C-674'

    include SentryLogging

    attr_reader :user_account,
                :va_profile_email,
                :first_name,
                :middle_name,
                :last_name,
                :icn,
                :ssn,
                :common_name,
                :participant_id,
                :saved_claim_id,
                :form_hash_686c

    def initialize(user_account:, # rubocop:disable Metrics/ParameterLists
                   va_profile_email:,
                   first_name:,
                   middle_name:,
                   last_name:,
                   icn:,
                   ssn:,
                   common_name:,
                   participant_id:,
                   saved_claim_id:,
                   form_hash_686c:)
      @user_account = user_account
      @va_profile_email = va_profile_email
      @first_name = first_name
      @middle_name = middle_name
      @last_name = last_name
      @icn = icn
      @ssn = ssn
      @common_name = common_name
      @participant_id = participant_id
      @saved_claim_id = saved_claim_id
      @form_hash_686c = form_hash_686c
    end

    def perform
      BGS::Form674.new(icn:,
                       ssn:,
                       common_name:,
                       first_name:,
                       middle_name:,
                       last_name:,
                       participant_id:).submit(valid_claim_data)
    rescue => e
      log_message_to_sentry(e, :error, {}, { team: Constants::SENTRY_REPORTING_TEAM })
      DependentsApplicationFailureMailer.build(email: va_profile_email, first_name:, last_name:).deliver_now
    end

    private

    def valid_claim_data
      claim = SavedClaim::DependencyClaim.find(saved_claim_id)

      claim.add_veteran_info(form_hash_686c)

      raise Invalid674Claim unless claim.valid?(:run_686_form_jobs)

      claim.formatted_674_data(form_hash_686c)
    end
  end
end
