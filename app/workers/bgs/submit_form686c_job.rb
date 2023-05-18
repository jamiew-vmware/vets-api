# frozen_string_literal: true

require 'bgs/form686c'

module BGS
  class SubmitForm686cJob
    class Invalid686cClaim < StandardError; end
    FORM_ID = '686C-674'
    include Sidekiq::Worker
    include SentryLogging

    sidekiq_options retry: false

    def perform(user_uuid, saved_claim_id, file_number) # rubocop:disable Metrics/MethodLength
      user = User.find(user_uuid)
      Rails.logger.info('BGS::SubmitForm686cJob running!', { user_uuid:, saved_claim_id:, icn: user&.icn })
      return unless user

      user_account = user.user_account
      icn = user.icn
      common_name = user.common_name
      participant_id = user.participant_id
      ssn = user.ssn
      first_name = user.first_name
      middle_name = user.middle_name
      last_name = user.last_name
      birth_date = user.birth_date
      va_profile_email = user.va_profile_email
      form_hash_686c = get_form_hash_686c(first_name:, middle_name:, last_name:, ssn:, file_number:, birth_date:)
      claim_data = valid_claim_data(saved_claim_id, form_hash_686c)

      BGS::Form686c.new(icn:,
                        common_name:,
                        participant_id:,
                        ssn:,
                        first_name:,
                        middle_name:,
                        last_name:).submit(claim_data)
      claim = SavedClaim::DependencyClaim.find(saved_claim_id)
      if claim.submittable_674?
        BGS::SubmitForm674.new(user_account:,
                               va_profile_email:,
                               first_name:,
                               middle_name:,
                               last_name:,
                               icn:,
                               ssn:,
                               common_name:,
                               participant_id:,
                               saved_claim_id:,
                               form_hash_686c:).perform
      end
      send_confirmation_email(va_profile_email:, first_name:, user_account:)
      destroy_in_progress_form(user_account:)
      Rails.logger.info('BGS::SubmitForm686cJob succeeded!', { user_uuid:, saved_claim_id:, icn: user&.icn })
    rescue => e
      Rails.logger.error('BGS::SubmitForm686cJob failed!',
                         { user_uuid:, saved_claim_id:, icn: user&.icn, error: e.message })
      log_message_to_sentry(e, :error, {}, { team: Constants::SENTRY_REPORTING_TEAM })
      DependentsApplicationFailureMailer.build(email: va_profile_email, first_name:, last_name:).deliver_now
    end

    private

    def destroy_in_progress_form(user_account:)
      InProgressForm.find_by(form_id: FORM_ID, user_account:)&.destroy
    end

    def valid_claim_data(saved_claim_id, form_hash_686c)
      claim = SavedClaim::DependencyClaim.find(saved_claim_id)

      claim.add_veteran_info(form_hash_686c)

      raise Invalid686cClaim unless claim.valid?(:run_686_form_jobs)

      claim.formatted_686_data(form_hash_686c)
    end

    def send_confirmation_email(va_profile_email:, first_name:, user_account:)
      return if va_profile_email.blank?

      VANotify::ConfirmationEmail.send(
        email_address: va_profile_email,
        template_id: Settings.vanotify.services.va_gov.template_id.form686c_confirmation_email,
        first_name: first_name&.upcase,
        user_account_uuid_and_form_id: "#{user_account.id}_#{FORM_ID}"
      )
    end

    def get_form_hash_686c(first_name:, middle_name:, last_name:, ssn:, file_number:, birth_date:) # rubocop:disable Metrics/ParameterLists
      {
        'veteran_information' => {
          'full_name' => {
            'first' => first_name,
            'middle' => middle_name,
            'last' => last_name
          },
          'ssn' => ssn,
          'va_file_number' => file_number,
          'birth_date' => birth_date
        }
      }
    end
  end
end
