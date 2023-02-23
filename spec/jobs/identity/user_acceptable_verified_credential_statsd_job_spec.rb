# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Identity::UserAcceptableVerifiedCredentialStatsdJob do
  shared_examples 'a successful run' do
    it 'initializes StatsD with expected key with expected count' do
      allow(StatsD).to receive(:increment)
      subject.perform

      expect(StatsD).to have_received(:increment).with(expected_key, expected_count).exactly(1).time
    end

    it 'logs expected message' do
      expect(Rails.logger).to receive(:info).with(expected_log_message, expected_log_payload)

      subject.perform
    end
  end

  shared_examples 'a combined statsD key' do
    it 'initializes StatsD with expected key with expected count' do
      allow(StatsD).to receive(:increment)
      subject.perform

      expect(StatsD).to have_received(:increment).with(expected_key, expected_count).exactly(1).time
    end

    it 'logs expected message' do
      expect(Rails.logger).to receive(:info).with(expected_log_message, expected_log_payload)

      subject.perform
    end
  end

  let(:expected_count) { 1 }
  let(:expected_log_message) { 'UserAcceptableVerifiedCredential - StatsD Initialized' }
  let(:expected_key) { "user_avc_updater.#{expected_provider}.#{expected_type}.added" }
  let!(:user_avc) do
    create(:user_acceptable_verified_credential, user_account: user_verification.user_account,
                                                 acceptable_verified_credential_at: expected_avc_at,
                                                 idme_verified_credential_at: expected_ivc_at)
  end
  let(:expected_avc_at) { nil }
  let(:expected_ivc_at) { nil }
  let(:expected_log_payload) do
    { 'user_avc_updater.dslogon.avc.added': expected_dslogon_avc_count,
      'user_avc_updater.dslogon.ivc.added': expected_dslogon_ivc_count,
      'user_avc_updater.idme.avc.added': expected_idme_avc_count,
      'user_avc_updater.idme.ivc.added': expected_idme_ivc_count,
      'user_avc_updater.logingov.avc.added': expected_logingov_avc_count,
      'user_avc_updater.logingov.ivc.added': expected_logingov_ivc_count,
      'user_avc_updater.mhv.avc.added': expected_mhv_avc_count,
      'user_avc_updater.mhv.ivc.added': expected_mhv_ivc_count,
      'user_avc_updater.mhv_dslogon.avc.added': expected_mhv_dslogon_avc_count,
      'user_avc_updater.mhv_dslogon.ivc.added': expected_mhv_dslogon_ivc_count }.as_json
  end
  let(:expected_dslogon_avc_count) { 0 }
  let(:expected_dslogon_ivc_count) { 0 }
  let(:expected_idme_avc_count) { 0 }
  let(:expected_idme_ivc_count) { 0 }
  let(:expected_logingov_avc_count) { 0 }
  let(:expected_logingov_ivc_count) { 0 }
  let(:expected_mhv_avc_count) { 0 }
  let(:expected_mhv_ivc_count) { 0 }
  let(:expected_mhv_dslogon_avc_count) { 0 }
  let(:expected_mhv_dslogon_ivc_count) { 0 }

  describe '#perform' do
    subject { described_class.new }

    context 'when idme user verification' do
      let(:user_verification) { create(:idme_user_verification) }
      let(:expected_provider) { 'idme' }

      context 'when ivc' do
        let(:expected_idme_ivc_count) { 1 }
        let(:expected_ivc_at) { Time.zone.today }
        let(:expected_type) { 'ivc' }

        it_behaves_like 'a successful run'
      end

      context 'when avc' do
        let(:expected_idme_avc_count) { 1 }
        let(:expected_avc_at) { Time.zone.today }
        let(:expected_type) { 'avc' }

        it_behaves_like 'a successful run'
      end
    end

    context 'when logingov user verification' do
      let(:user_verification) { create(:logingov_user_verification) }
      let(:expected_provider) { 'logingov' }

      context 'when ivc' do
        let(:expected_logingov_ivc_count) { 1 }
        let(:expected_ivc_at) { Time.zone.today }
        let(:expected_type) { 'ivc' }

        it_behaves_like 'a successful run'
      end

      context 'when avc' do
        let(:expected_logingov_avc_count) { 1 }
        let(:expected_avc_at) { Time.zone.today }
        let(:expected_type) { 'avc' }

        it_behaves_like 'a successful run'
      end
    end

    context 'when mhv user verification' do
      let(:user_verification) { create(:mhv_user_verification) }
      let(:expected_provider) { 'mhv' }

      context 'when ivc' do
        let(:expected_mhv_ivc_count) { 1 }
        let(:expected_mhv_dslogon_ivc_count) { 1 }
        let(:expected_ivc_at) { Time.zone.today }
        let(:expected_type) { 'ivc' }

        it_behaves_like 'a successful run'

        context 'when there is a combined key' do
          let(:expected_provider) { 'mhv_dslogon' }

          it_behaves_like 'a combined statsD key'
        end
      end

      context 'when avc' do
        let(:expected_mhv_avc_count) { 1 }
        let(:expected_mhv_dslogon_avc_count) { 1 }
        let(:expected_avc_at) { Time.zone.today }
        let(:expected_type) { 'avc' }

        it_behaves_like 'a successful run'

        context 'when there is a combined key' do
          let(:expected_provider) { 'mhv_dslogon' }

          it_behaves_like 'a combined statsD key'
        end
      end
    end

    context 'when dslogon user verification' do
      let(:user_verification) { create(:dslogon_user_verification) }
      let(:expected_provider) { 'dslogon' }

      context 'when ivc' do
        let(:expected_dslogon_ivc_count) { 1 }
        let(:expected_mhv_dslogon_ivc_count) { 1 }
        let(:expected_ivc_at) { Time.zone.today }
        let(:expected_type) { 'ivc' }

        it_behaves_like 'a successful run'

        context 'when there is a combined key' do
          let(:expected_provider) { 'mhv_dslogon' }

          it_behaves_like 'a combined statsD key'
        end
      end

      context 'when avc' do
        let(:expected_dslogon_avc_count) { 1 }
        let(:expected_mhv_dslogon_avc_count) { 1 }
        let(:expected_avc_at) { Time.zone.today }
        let(:expected_type) { 'avc' }

        it_behaves_like 'a successful run'

        context 'when there is a combined key' do
          let(:expected_provider) { 'mhv_dslogon' }

          it_behaves_like 'a combined statsD key'
        end
      end
    end
  end
end
