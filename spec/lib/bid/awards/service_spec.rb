# frozen_string_literal: true

require 'rails_helper'
require 'bid/awards/service'

RSpec.describe BID::Awards::Service do
  let(:user) { FactoryBot.create(:evss_user, :loa3) }
  let(:participant_id) { user.participant_id }
  let(:service) { BID::Awards::Service.new }

  describe '#get_awards_pension' do
    let(:faraday_response) { double('faraday_connection') }

    before do
      allow(faraday_response).to receive(:env)
    end

    context 'with a successful submission' do
      it 'successfully receives an Award Pension object' do
        VCR.use_cassette('bid/awards/get_awards_pension') do
          response = service.get_awards_pension(participant_id:)

          expect(response.status).to eq(200)
          expect(response.body['awards_pension']['is_eligible_for_pension']).to eq(true)
          expect(response.body['awards_pension']['is_in_receipt_of_pension']).to eq(true)
        end
      end
    end
  end
end
