# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGS::SubmitForm686cJob, type: :job do
  subject { described_class.new.perform(user.uuid, dependency_claim.id, file_number) }

  let!(:user) { FactoryBot.create(:evss_user, :loa3) }
  let!(:user_verification) { create(:user_verification, idme_uuid: user.idme_uuid) }
  let(:icn) { user.icn }
  let(:common_name) { user.common_name }
  let(:participant_id) { user.participant_id }
  let(:ssn) { user.ssn }
  let(:first_name) { user.first_name }
  let(:middle_name) { user.middle_name }
  let(:last_name) { user.last_name }
  let(:email) { user.va_profile_email }
  let(:dependency_claim) { create(:dependency_claim) }
  let(:all_flows_payload) { FactoryBot.build(:form_686c_674_kitchen_sink) }
  let(:file_number) { '796043735' }

  before do
    allow_any_instance_of(SavedClaim::DependencyClaim).to receive(:submittable_674?).and_return(false)
  end

  it 'calls #submit for 686c submission' do
    client_stub = instance_double('BGS::Form686c')
    allow(BGS::Form686c).to receive(:new).with(icn:,
                                               common_name:,
                                               participant_id:,
                                               ssn:,
                                               first_name:,
                                               middle_name:,
                                               last_name:) { client_stub }
    expect(client_stub).to receive(:submit).once

    subject
  end

  it 'sends confirmation email' do
    client_stub = instance_double('BGS::Form686c')
    allow(BGS::Form686c).to receive(:new).with(icn:,
                                               common_name:,
                                               participant_id:,
                                               ssn:,
                                               first_name:,
                                               middle_name:,
                                               last_name:) { client_stub }
    expect(client_stub).to receive(:submit).once

    expect(VANotify::EmailJob).to receive(:perform_async).with(
      email,
      'fake_template_id',
      {
        'date' => Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%B %d, %Y'),
        'first_name' => 'WESLEY'
      }
    )

    subject
  end

  context 'Claim is submittable_674' do
    it 'makes a call to SubmitForm674' do
      allow_any_instance_of(SavedClaim::DependencyClaim).to receive(:submittable_674?).and_return(true)
      client_stub = instance_double('BGS::Form686c')
      allow(BGS::Form686c).to receive(:new).with(icn:,
                                                 common_name:,
                                                 participant_id:,
                                                 ssn:,
                                                 first_name:,
                                                 middle_name:,
                                                 last_name:) { client_stub }
      expect(client_stub).to receive(:submit).once
      expect_any_instance_of(BGS::SubmitForm674).to receive(:perform)

      subject
    end
  end

  context 'Claim is not submittable_674' do
    it 'does not make a call to SubmitForm674' do
      client_stub = instance_double('BGS::Form686c')
      allow(BGS::Form686c).to receive(:new).with(icn:,
                                                 common_name:,
                                                 participant_id:,
                                                 ssn:,
                                                 first_name:,
                                                 middle_name:,
                                                 last_name:) { client_stub }
      expect(client_stub).to receive(:submit).once
      expect_any_instance_of(BGS::SubmitForm674).not_to receive(:perform)

      subject
    end
  end

  context 'when submission raises error' do
    it 'calls DependentsApplicationFailureMailer' do
      client_stub = instance_double('BGS::Form686c')
      mailer_double = double('Mail::Message')
      allow(BGS::Form686c).to receive(:new).with(icn:,
                                                 common_name:,
                                                 participant_id:,
                                                 ssn:,
                                                 first_name:,
                                                 middle_name:,
                                                 last_name:) { client_stub }
      expect(client_stub).to receive(:submit).and_raise(StandardError)

      allow(mailer_double).to receive(:deliver_now)
      expect(DependentsApplicationFailureMailer).to receive(:build).with(email:,
                                                                         first_name:,
                                                                         last_name:) { mailer_double }

      subject
    end
  end
end
