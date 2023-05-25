# frozen_string_literal: true

class VANotifyReactivationEmailJob
  include Sidekiq::Worker
  extend SentryLogging
  sidekiq_options retry: 14

  def perform
    notify_client = VaNotify::Service.new(Settings.vanotify.services.va_gov.api_key)
    template_id = Settings.vanotify.services.va_gov.template_id.public_send('generic')

    notify_client.send_email(
      email_address: 'kcoulter@pluribusdigital.com',
      template_id:
    )
  end
end
