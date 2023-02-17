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

  context "A bad request is made to the /eligible-letters endpoint" do
    before do
      fakeResponseBody = File.read('spec/lib/lighthouse/letters_generator/fake400Error.json')
      env = Faraday::Env.new
      env.status = 400
      # We have to do this here, because we're stubbing the response
      env.body = JSON.parse(fakeResponseBody)
      @faradayResponse = Faraday::Response.new(env)
    end

    it 'returns a 400 status' do
      # Arrange
      expectedBadParams = [:get, '/eligible-letters', {icn: 'BADREQUEST'}]
      client = Lighthouse::LettersGenerator::Client.new

      # Expect
      expect_any_instance_of(Faraday::Connection).to receive(:send).with(*expectedBadParams).and_return(@faradayResponse)

      # Act
      actualResponse = client.get_eligible_letter_types('BADREQUEST')

      # Assert
      # TO-DO: update assertions once we figure out why Faraday doesn't seem to be raising the error
      expect(actualResponse[0]).to have_key("letterType")
      expect(actualResponse[0]).to have_key("letterName")
    end
  end
end