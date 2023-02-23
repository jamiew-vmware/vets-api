# frozen_string_literal: true

module Identity
  class UserAcceptableVerifiedCredentialStatsdJob
    include Sidekiq::Worker

    STATSD_KEY_PREFIX = 'user_avc_updater'
    PROVIDERS = [IDME = 'idme', LOGINGOV = 'logingov', DSLOGON = 'dslogon', MHV = 'mhv'].freeze
    AVC_TYPE = 'avc'
    IVC_TYPE = 'ivc'

    def perform
      initialize_statsd

      Rails.logger.info('UserAcceptableVerifiedCredential - StatsD Initialized', log_payload)
    end

    private

    def initialize_statsd # rubocop:disable Metrics/MethodLength
      combined_ivc_total = 0
      combined_avc_total = 0

      PROVIDERS.each do |provider|
        verifications = UserAcceptableVerifiedCredential.joins(user_account: :user_verifications)
                                                        .merge(UserVerification.public_send(provider)).distinct
        # AVC
        avc_count = verifications.where.not(acceptable_verified_credential_at: nil).count
        avc_key = "#{STATSD_KEY_PREFIX}.#{provider}.#{AVC_TYPE}.added"
        StatsD.increment(avc_key, avc_count)
        log_payload[avc_key] = avc_count

        # IVC
        ivc_count = verifications.where.not(idme_verified_credential_at: nil).count
        ivc_key = "#{STATSD_KEY_PREFIX}.#{provider}.#{IVC_TYPE}.added"
        StatsD.increment(ivc_key, ivc_count)
        log_payload[ivc_key] = ivc_count

        # MHV and DSLOGON combined
        if [MHV, DSLOGON].include?(provider)
          combined_avc_total += avc_count
          combined_ivc_total += ivc_count
        end
      end

      # AVC Combined
      avc_combined_key = "#{STATSD_KEY_PREFIX}.#{MHV}_#{DSLOGON}.#{AVC_TYPE}.added"
      StatsD.increment(avc_combined_key, combined_avc_total)
      log_payload[avc_combined_key] = combined_avc_total

      # IVC Combined
      ivc_combined_key = "#{STATSD_KEY_PREFIX}.#{MHV}_#{DSLOGON}.#{IVC_TYPE}.added"
      StatsD.increment(ivc_combined_key, combined_ivc_total)
      log_payload[ivc_combined_key] = combined_ivc_total
    end

    def log_payload
      @log_payload ||= {}
    end
  end
end
