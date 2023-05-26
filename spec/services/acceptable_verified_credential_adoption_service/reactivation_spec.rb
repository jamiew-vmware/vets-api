# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AcceptableVerifiedCredentialAdoptionService, '.reactivation' do
  let(:service) { AcceptableVerifiedCredentialAdoptionService.new(user) }
  let(:user) { create(:user, :dslogon) }
  let(:user_verification) { create(:dslogon_user_verification, dslogon_uuid: user.edipi) }
  let!(:user_account) { user_verification.user_account }

  describe 'Reactivation Qualification' do
    context 'User is dslogon authenticated' do
      context 'When user has avc' do
        let!(:user_acceptable_verified_credential) do
          create(:user_acceptable_verified_credential, :with_avc, user_account:)
        end

        it 'hash returns false' do
          expect(service.perform).to include(reactivation_email: true)
        end

        it 'hash returns correct credential type - dslogon' do
          expect(service.perform).to include(credential_type: SAML::User::DSLOGON_CSID)
        end
      end

      context 'When user has ivc' do
        let!(:user_acceptable_verified_credential) do
          create(:user_acceptable_verified_credential, :with_ivc, user_account:)
        end

        it 'hash returns false' do
          expect(service.perform).to include(reactivation_email: true)
        end

        it 'hash returns correct credential type - dslogon' do
          expect(service.perform).to include(credential_type: SAML::User::DSLOGON_CSID)
        end
      end

      context 'When user has no avc/ivc' do
        let!(:user_acceptable_verified_credential) do
          create(:user_acceptable_verified_credential, :without_avc_ivc, user_account:)
        end

        it 'hash returns true' do
          expect(service.perform).to include(reactivation_email: false)
        end

        it 'hash returns correct credential type - dslogon' do
          expect(service.perform).to include(credential_type: SAML::User::DSLOGON_CSID)
        end
      end
    end

    context 'When user is login.gov authenticated' do
      let(:user) { create(:user, :accountable_with_logingov_uuid, authn_context: IAL::LOGIN_GOV_IAL2) }
      let(:user_verification) { create(:logingov_user_verification, logingov_uuid: user.logingov_uuid) }
      let!(:user_acceptable_verified_credential) do
        create(:user_acceptable_verified_credential, :with_avc, user_account:)
      end

      it 'hash returns false' do
        expect(service.perform).to include(reactivation_email: false)
      end

      it 'hash returns correct credential type - login.gov' do
        expect(service.perform).to include(credential_type: SAML::User::LOGINGOV_CSID)
      end
    end

    context 'When user is idme authenticated' do
      let(:user) { create(:user, :accountable, authn_context: LOA::IDME_LOA3_VETS) }
      let(:user_verification) { create(:idme_user_verification, idme_uuid: user.idme_uuid) }
      let!(:user_acceptable_verified_credential) do
        create(:user_acceptable_verified_credential, :with_ivc, user_account:)
      end

      it 'hash returns false' do
        expect(service.perform).to include(reactivation_email: false)
      end

      it 'hash returns correct credential type - idme' do
        expect(service.perform).to include(credential_type: SAML::User::IDME_CSID)
      end
    end

    context 'User is mhv authenticated' do
      context 'When user has avc' do
        let(:user) { create(:user, :mhv, authn_context: SAML::User::MHV_ORIGINAL_CSID) }
        let(:user_verification) { create(:mhv_user_verification, mhv_uuid: user.mhv_correlation_id) }
        let!(:user_acceptable_verified_credential) do
          create(:user_acceptable_verified_credential, :with_avc, user_account:)
        end

        it 'hash returns false' do
          expect(service.perform).to include(reactivation_email: true)
        end

        it 'hash returns correct credential type - mhv' do
          expect(service.perform).to include(credential_type: SAML::User::MHV_ORIGINAL_CSID)
        end
      end
    end

    context 'When user has ivc' do
      let(:user) { create(:user, :mhv, authn_context: SAML::User::MHV_ORIGINAL_CSID) }
      let(:user_verification) { create(:mhv_user_verification, mhv_uuid: user.mhv_correlation_id) }
      let!(:user_acceptable_verified_credential) do
        create(:user_acceptable_verified_credential, :with_ivc, user_account:)
      end

      it 'hash returns false' do
        expect(service.perform).to include(reactivation_email: true)
      end

      it 'hash returns correct credential type - mhv' do
        expect(service.perform).to include(credential_type: SAML::User::MHV_ORIGINAL_CSID)
      end
    end

    context 'When user has no avc/ivc' do
      let(:user) { create(:user, :mhv, authn_context: SAML::User::MHV_ORIGINAL_CSID) }
      let(:user_verification) { create(:mhv_user_verification, mhv_uuid: user.mhv_correlation_id) }
      let!(:user_acceptable_verified_credential) do
        create(:user_acceptable_verified_credential, :without_avc_ivc, user_account:)
      end

      it 'hash returns true' do
        expect(service.perform).to include(reactivation_email: false)
      end

      it 'hash returns correct credential type - mhv' do
        expect(service.perform).to include(credential_type: SAML::User::MHV_ORIGINAL_CSID)
      end
    end
  end
end
