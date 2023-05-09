# frozen_string_literal: true

LighthousePolicy = Struct.new(:user, :lighthouse) do
  def access?
    user.icn.present? && user.participant_id.present?
  end

  def access_disability_compensations?
    user.loa3? &&
      allowed_providers.include?(user.identity.sign_in[:service_name]) &&
      user.icn.present? && user.participant_id.present?
  end

  def access_update?
    res = Mobile::V0::LighthouseDirectDeposit::Service.new(user.icn).get_payment_information

    res.control_information.authorized?
  end

  private

  def allowed_providers
    %w[
      idme
      oauth_IDME
      logingov
      oauth_LOGINGOV
    ].freeze
  end
end
