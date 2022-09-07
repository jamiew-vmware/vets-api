# frozen_string_literal: true

require 'evss/disability_compensation_form/service_exception'
require 'evss/disability_compensation_form/gateway_timeout'
require 'sentry_logging'

module EVSS
  module DisabilityCompensationForm
    class SubmitForm526 < Job
      # Sidekiq has built in exponential back-off functionality for retrys
      # A max retry attempt of 15 will result in a run time of ~36 hours
      RETRY = 15
      STATSD_KEY_PREFIX = 'worker.evss.submit_form526'

      sidekiq_options retry: RETRY, queue: 'low'

      # This callback cannot be tested due to the limitations of `Sidekiq::Testing.fake!`
      # :nocov:
      sidekiq_retries_exhausted do |msg, _ex|
        submission = nil
        next_birls_jid = nil

        # log, mark Form526JobStatus for submission as "exhausted"
        begin
          job_exhausted(msg, STATSD_KEY_PREFIX)
        rescue => e
          log_exception_to_sentry(e)
        end

        # Submit under different birls if avail
        begin
          submission = Form526Submission.find msg['args'].first
          next_birls_jid = submission.submit_with_birls_id_that_hasnt_been_tried_yet!(
            silence_errors_and_log_to_sentry: true,
            extra_content_for_sentry: { job_class: msg['class'].demodulize, job_id: msg['jid'] }
          )
        rescue => e
          log_exception_to_sentry(e)
        end

        # if no more unused birls to attempt submit with, give up, let vet know
        begin
          notify_enabled = Flipper.enabled?(:disability_compensation_pif_fail_notification)
          if submission && next_birls_jid.nil? && msg['error_message'] == 'PIF in use' && notify_enabled
            first_name = submission.get_first_name&.capitalize || 'Sir or Madam'
            params = submission.personalization_parameters(first_name)
            Form526SubmissionFailedEmailJob.perform_async(params)
          end
        rescue => e
          log_exception_to_sentry(e)
        end
      end
      # :nocov:

      # Performs an asynchronous job for submitting a form526 to an upstream
      # submission service (currently EVSS)
      #
      # @param submission_id [Integer] The {Form526Submission} id
      #
      def perform(submission_id)
        Raven.tags_context(source: '526EZ-all-claims')
        super(submission_id)

        # this should only be checked once before evss submission because of the pending_eps check.
        # after submitting to evss, the claim is sometimes put into a pending_ep state
        forward_to_mas = forward_to_mas?(submission)
        submission.insert_classification_codes if forward_to_mas
        with_tracking('Form526 Submission', submission.saved_claim_id, submission.id, submission.bdd?) do
          service = service(submission.auth_headers)
          submission.mark_birls_id_as_tried!
          response = service.submit_form526(submission.form_to_json(Form526Submission::FORM_526))
          response_handler(response)
        end
        send_notifications(submission, forward_to_mas)
      rescue Common::Exceptions::BackendServiceException,
             Common::Exceptions::GatewayTimeout,
             Breakers::OutageException,
             EVSS::DisabilityCompensationForm::ServiceUnavailableException => e
        retryable_error_handler(submission, e)
      rescue EVSS::DisabilityCompensationForm::ServiceException => e
        # retry submitting the form for specific upstream errors
        retry_form526_error_handler!(submission, e)
      rescue => e
        non_retryable_error_handler(submission, e)
      end

      private

      def send_notifications(submission, forward_to_mas)
        send_rrd_completed_notification(submission) if submission.rrd_job_selector.rrd_applicable?
        submission.notify_mas if forward_to_mas
        send_rrd_pact_related_notification(submission) if rrd_new_pact_related_disability?(submission)
      end

      def forward_to_mas?(submission)
        return false unless Flipper.enabled?(:rrd_mas_disability_tracking)

        # only use the first diagnostic code because we can only support single-issue claims

        submission.diagnostic_codes.size == 1 &&
          RapidReadyForDecision::Constants::MAS_DISABILITIES.include?(submission.diagnostic_codes.first) &&
          submission.disabilities.first['disabilityActionType']&.upcase == 'INCREASE' &&
          !submission.pending_eps? &&
          !disability_not_service_connected?
      end

      def disability_not_service_connected?
        rated_disability_id = submission.disabilities.first['ratedDisabilityId']
        response = service(submission.auth_headers).get_rated_disabilities
        disabilities = response.rated_disabilities
        disability = disabilities.find { |dis| dis.rated_disability_id == rated_disability_id }
        disability&.decision_code == 'NOTSVCCON'
      end

      def rrd_new_pact_related_disability?(submission)
        return false unless Flipper.enabled?(:rrd_new_pact_related_disability)

        submission.disabilities.any? do |disability|
          disability['disabilityActionType']&.upcase == 'NEW' &&
            (RapidReadyForDecision::Constants::PACT_CLASSIFICATION_CODES.include? disability['classificationCode'])
        end
      end

      def send_rrd_completed_notification(submission)
        RrdCompletedMailer.build(submission).deliver_now
      end

      def send_rrd_pact_related_notification(submission)
        icn = RapidReadyForDecision::ClaimContext.new(submission).user_icn
        client = Lighthouse::VeteransHealth::Client.new(icn)
        bp_readings = RapidReadyForDecision::LighthouseObservationData.new(client.list_bp_observations).transform
        meds = RapidReadyForDecision::LighthouseMedicationRequestData.new(client.list_medication_requests).transform

        RrdNewDisabilityClaimMailer.build(submission, {
                                            bp_readings_count: bp_readings.length,
                                            medications_count: meds.length
                                          }).deliver_now
      end

      def response_handler(response)
        submission.submitted_claim_id = response.claim_id
        submission.save
      end

      def retryable_error_handler(_submission, error)
        # update JobStatus, log and metrics in JobStatus#retryable_error_handler
        super(error)
        raise error
      end

      def non_retryable_error_handler(submission, error)
        # update JobStatus, log and metrics in JobStatus#non_retryable_error_handler
        super(error)
        send_rrd_alert(submission, error, 'non-retryable') if submission.rrd_job_selector.rrd_applicable?
        submission.submit_with_birls_id_that_hasnt_been_tried_yet!(
          silence_errors_and_log_to_sentry: true,
          extra_content_for_sentry: { job_class: self.class.to_s.demodulize, job_id: jid }
        )
      end

      def send_rrd_alert(submission, error, subtitle)
        message = "RRD could not submit the claim to EVSS: #{subtitle}<br/>"
        submission.send_rrd_alert_email("RRD submission to EVSS error: #{subtitle}", message, error)
      end

      def service(_auth_headers)
        raise NotImplementedError, 'Subclass of SubmitForm526 must implement #service'
      end

      # Logic for retrying a job due to an upstream service error.
      # Retry if any upstream external service unavailability exceptions (unless it is caused by an invalid EP code)
      # and any PIF-in-use exceptions are encountered.
      # Otherwise the job is marked as non-retryable and completed.
      #
      # @param error [EVSS::DisabilityCompensationForm::ServiceException]
      #
      def retry_form526_error_handler!(submission, error)
        if error.retryable?
          retryable_error_handler(submission, error)
        else
          non_retryable_error_handler(submission, error)
        end
      end
    end
  end
end
