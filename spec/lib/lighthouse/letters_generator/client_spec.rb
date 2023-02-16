# frozen_string_literal true
require 'rails_helper'
require 'lighthouse/letters_generator/client'

RSpec.describe Lighthouse::LettersGenerator::Client do
  context "the request to Lighthouse succeeds" do
    before do
      fakeResponseBody = File.read('spec/lib/lighthouse/letters_generator/fakeResponse.json')
      env = Faraday::Env.new
      env.status = 200
      # We have to do this here, because we're stubbing the response
      env.body = JSON.parse(fakeResponseBody)
      @faradayResponse = Faraday::Response.new(env)
    end

    it 'returns a list of eligible letter types' do
      # Arrange
      expectedDollyParams = [:get, '/eligible-letters', {icn: 'DOLLYPARTON'}]
      client = Lighthouse::LettersGenerator::Client.new

      # Expect
      expect_any_instance_of(Faraday::Connection).to receive(:send).with(*expectedDollyParams).and_return(@faradayResponse)

      # Act
      actualDollyTypes = client.get_eligible_letter_types('DOLLYPARTON')

      # Assert
      expect(actualDollyTypes[0]).to have_key("letterType")
      expect(actualDollyTypes[0]).to have_key("letterName")
    end
  end

  context "the request to Lighthouse failes"
end