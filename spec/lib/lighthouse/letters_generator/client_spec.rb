# frozen_string_literal true
require 'rails_helper'
require 'lighthouse/letters_generator/client'

RSpec.describe Lighthouse::LettersGenerator::Client do
  
  before do
    @faradayResponse = instance_double('Faraday::Response')
    allow(@faradayResponse).to receive(:env).and_return('dev')
  end

  it 'returns a list of eligible letter types' do
    # Arrange
    expectedDollyParams = [:get, '/eligible-letters', {icn: 'DOLLYPARTON'}]
    client = Lighthouse::LettersGenerator::Client.new

    # Expect
    expect_any_instance_of(Faraday::Connection).to receive(:send).with(*expectedDollyParams).and_return(@faradayResponse)

    # Act
    actualDollyTypes = client.get_eligible_letter_types('DOLLYPARTON')
  end
end