# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGS::SubmitForm674 do
  subject do
    described_class.new(user_account:,
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
  end

  let(:user) { FactoryBot.create(:evss_user, :loa3) }
  let(:dependency_claim) { create(:dependency_claim) }
  let(:all_flows_payload) { FactoryBot.build(:form_686c_674_kitchen_sink) }
  let(:form_hash_686c) do
    {
      'veteran_information' => {
        'birth_date' => '1809-02-12',
        'full_name' => {
          'first' => 'WESLEY', 'last' => 'FORD', 'middle' => nil
        },
        'ssn' => '796043735',
        'va_file_number' => '796043735'
      }
    }
  end
  let(:user_account) { user.user_account }
  let(:va_profile_email) { user.va_profile_email }
  let(:first_name) { user.first_name }
  let(:middle_name) { user.middle_name }
  let(:last_name) { user.last_name }
  let(:icn) { user.icn }
  let(:ssn) { user.ssn }
  let(:common_name) { user.common_name }
  let(:participant_id) { user.participant_id }
  let(:bgs_form674) { instance_double(BGS::Form674) }
  let(:saved_claim_id) { dependency_claim.id }

  before do
    allow(BGS::Form674).to receive(:new).with(first_name:,
                                              middle_name:,
                                              last_name:,
                                              icn:,
                                              ssn:,
                                              common_name:,
                                              participant_id:).and_return(bgs_form674)
  end

  it 'calls #submit for 674 submission' do
    expect(bgs_form674).to receive(:submit).once
    subject.perform
  end

  context 'error' do
    before do
      InProgressForm.create!(form_id: '686C-674', user_uuid: user.uuid, form_data: all_flows_payload)
    end

    it 'calls #submit for 674 submission' do
      submit_form_instance = subject
      mailer_double = double(Mail::Message)
      expect(bgs_form674).to receive(:submit).and_raise(StandardError)
      allow(mailer_double).to receive(:deliver_now)
      expect(DependentsApplicationFailureMailer).to receive(:build).with(email: va_profile_email,
                                                                         first_name:,
                                                                         last_name:) { mailer_double }
      submit_form_instance.perform
    end
  end
end
