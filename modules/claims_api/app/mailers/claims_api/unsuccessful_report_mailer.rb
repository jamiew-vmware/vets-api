# frozen_string_literal: true

module ClaimsApi
  class UnsuccessfulReportMailer < ApplicationMailer
    RECIPIENTS = %w[
      alex.wilson@oddball.io
      austin.covrig@oddball.io
      david.mazik@va.gov
      emily.goodrich@oddball.io
      janet.coutinho@va.gov
      jennica.stiehl@oddball.io
      kayla.watanabe@adhocteam.us
      matt.king@adhocteam.us
      premal.shah@va.gov
      robert.perea-martinez@adhocteam.us
      stone_christopher@bah.com
      zachary.goldfine@va.gov
    ].freeze

    def build(date_from, date_to, data)
      @date_from = date_from.in_time_zone('Eastern Time (US & Canada)').strftime('%a %D %I:%M %p')
      @date_to = date_to.in_time_zone('Eastern Time (US & Canada)').strftime('%a %D %I:%M %p')
      @consumer_claims_totals = data[:consumer_claims_totals]
      @unsuccessful_claims_submissions = data[:unsuccessful_claims_submissions]
      @poa_totals = data[:poa_totals]
      @unsuccessful_poa_submissions = data[:unsuccessful_poa_submissions]
      @itf_totals = data[:itf_totals]

      template = File.read(path)
      body = ERB.new(template).result(binding)

      mail(
        to: RECIPIENTS,
        subject: 'Benefits Claims Daily Submission Report',
        content_type: 'text/html',
        body: body
      )
    end

    private

    def path
      ClaimsApi::Engine.root.join(
        'app',
        'views',
        'claims_api',
        'unsuccessful_report_mailer',
        'unsuccessful_report.html.erb'
      )
    end
  end
end
