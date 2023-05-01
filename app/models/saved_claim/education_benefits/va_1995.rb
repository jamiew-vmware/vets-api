# frozen_string_literal: true

class SavedClaim::EducationBenefits::VA1995 < SavedClaim::EducationBenefits
  add_form_and_validation('22-1995')

  # pulled from https://github.com/department-of-veterans-affairs/vets-website/blob/f27b8a5ffe4e2f9357d6c501c9a6a73dacdad0e1/src/applications/edu-benefits/utils/helpers.jsx#L100
  BENEFIT_TITLE_FOR_1995 = {
    'chapter30' => 'Montgomery GI Bill (MGIB or Chapter 30) Education Assistance Program',
    'chapter33' => 'Post-9/11 GI Bill (Chapter 33)',
    'chapter1606' => 'Montgomery GI Bill Selected Reserve (MGIB-SR or Chapter 1606) Educational Assistance Program',
    'chapter32' => 'Post-Vietnam Era Veterans’ Educational Assistance Program (VEAP or chapter 32)'
  }.freeze

  def after_submit(_user)
    parsed_form_data ||= JSON.parse(form)
    email = parsed_form_data['email']
    return if email.blank?

    return unless Flipper.enabled?(:form1995_confirmation_email)

    send_confirmation_email(parsed_form_data, email)
  end

  private

  def send_confirmation_email(parsed_form_data, email)

    VANotify::EmailJob.perform_async(
      email,
      Settings.vanotify.services.va_gov.template_id.form1995_confirmation_email,
      {
        'first_name' => parsed_form.dig('veteranFullName', 'first')&.upcase.presence,
        'benefits' => benefits_claimed(parsed_form_data),
        'benefit_relinquished' => '',
        'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
        'confirmation_number' => education_benefits_claim.confirmation_number,
        'regional_office_address' => regional_office_address
      }
    )
  end

  def benefits_claimed(parsed_form_data)
    %w[chapter30 chapter33 chapter1606 chapter32]
      .map { |benefit| parsed_form_data[benefit] ? BENEFIT_TITLE_FOR_1995[benefit] : nil }
      .compact
      .join("\n\n^")
  end
end
