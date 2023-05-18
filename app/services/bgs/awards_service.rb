# frozen_string_literal: true

module BGS
  class AwardsService
    include SentryLogging

    attr_reader :participant_id, :ssn, :common_name, :email, :icn

    def initialize(participant_id:, ssn:, common_name:, email:, icn:)
      @participant_id = participant_id
      @ssn = ssn
      @common_name = common_name
      @email = email
      @icn = icn
    end

    def get_awards
      service.awards.find_award_by_participant_id(participant_id, ssn) || service.awards.find_award_by_ssn(ssn)
    rescue => e
      log_exception_to_sentry(e, { icn: }, { team: Constants::SENTRY_REPORTING_TEAM })
      false
    end

    private

    def service
      @service ||= BGS::Services.new(external_uid: icn, external_key:)
    end

    def external_key
      @external_key ||= common_name.first(Constants::EXTERNAL_KEY_MAX_LENGTH)
    end
  end
end
