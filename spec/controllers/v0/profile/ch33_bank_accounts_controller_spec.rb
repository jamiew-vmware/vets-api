# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Profile::Ch33BankAccountsController, type: :controller do
  let(:user) { FactoryBot.build(:user, :loa3, first_name:, middle_name:, last_name:, suffix:, ssn:, icn:) }
  let(:suffix) { nil }
  let(:first_name) { 'abraham.lincoln@vets.gov' }
  let(:middle_name) { nil }
  let(:last_name) { nil }
  let(:ssn) { '796104437' }
  let(:icn) { '82836359962678900' }

  before do
    sign_in_as(user)
    allow(BGS.configuration).to receive(:env).and_return('prepbepbenefits')
    allow(BGS.configuration).to receive(:client_ip).and_return('10.247.35.119')
  end

  context 'unauthorized user' do
    def self.expect_unauthorized
      it 'returns unauthorized' do
        get(:index)
        expect(response.status).to eq(403)
        put(:update)
        expect(response.status).to eq(403)
      end
    end

    context 'with a loa1 user' do
      let(:user) { build(:user, :loa1) }

      expect_unauthorized
    end

    context 'with a non idme user' do
      let(:user) { build(:user, :loa3, :mhv) }

      expect_unauthorized
    end
  end

  describe '#index' do
    it 'returns the right data' do
      VCR.use_cassette('bgs/service/find_ch33_dd_eft', VCR::MATCH_EVERYTHING) do
        VCR.use_cassette('bgs/ddeft/find_bank_name_valid', VCR::MATCH_EVERYTHING) do
          get(:index)
        end
      end

      expect(JSON.parse(response.body)).to eq(
        {
          'data' => {
            'id' => '', 'type' => 'hashes',
            'attributes' => {
              'account_type' => 'Checking',
              'account_number' => '123',
              'financial_institution_name' => 'BANK OF AMERICA, N.A.',
              'financial_institution_routing_number' => '*****0724'
            }
          }
        }
      )
    end
  end

  describe '#update' do
    def send_update
      put(
        :update,
        params: {
          account_type: 'Checking',
          account_number: '444',
          financial_institution_routing_number: '122239982'
        }
      )
    end

    def send_successful_update
      VCR.use_cassette('bgs/service/update_ch33_dd_eft', VCR::MATCH_EVERYTHING) do
        VCR.use_cassette('bgs/service/find_ch33_dd_eft', VCR::MATCH_EVERYTHING) do
          VCR.use_cassette('bgs/ddeft/find_bank_name_valid', VCR::MATCH_EVERYTHING) do
            send_update
          end
        end
      end
    end

    context 'with a successful update' do
      it 'sends confirmation emails to the vanotify job' do
        expect(VANotifyDdEmailJob).to receive(:send_to_emails).with(
          user.all_emails, :ch33
        )

        send_successful_update
      end

      it 'submits the update req and rerenders index' do
        send_successful_update

        expect(JSON.parse(response.body)).to eq(
          {
            'data' => {
              'id' => '', 'type' => 'hashes',
              'attributes' => {
                'account_type' => 'Checking',
                'account_number' => '123',
                'financial_institution_name' => 'BANK OF AMERICA, N.A.',
                'financial_institution_routing_number' => '*****0724'
              }
            }
          }
        )
      end
    end

    context 'when there is an update error' do
      it 'renders the error message' do
        res = {
          update_ch33_dd_eft_response: {
            return: {
              return_code: 'F',
              error_message: 'Invalid routing number',
              return_message: 'FAILURE'
            },
            '@xmlns:ns0': 'http://services.share.benefits.vba.va.gov/'
          }
        }

        expect_any_instance_of(BGS::Service).to receive(:update_ch33_dd_eft).with(
          routing_number: '122239982',
          account_number: '444',
          checking_account: true,
          ssn: user.ssn
        ).and_return(
          OpenStruct.new(
            body: res
          )
        )

        send_update

        expect(response.status).to eq(400)
        expect(JSON.parse(response.body)).to eq(res.deep_stringify_keys)
      end
    end
  end
end
