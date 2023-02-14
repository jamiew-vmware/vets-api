# frozen_string_literal true
require 'rails_helper'
require 'lighthouse/letters_generator/client'

RSpec.describe Lighthouse::LettersGenerator::Client do
  it 'returns a list of eligible letter types' do
    # Arrange
    client = Lighthouse::LettersGenerator::Client.new('RHIANNA')
    fakeTypes = %w[A B C]

    # Act
    actualTypes = client.get_eligible_letter_types

    # Assert
    expect(actualTypes).to eq(fakeTypes)
  end

  it 'returns the correct letter types for a user' do
    user1_fake_types = %w[A B C]
    user2_fake_types = %w[D E F]

    client1 = Lighthouse::LettersGenerator::Client.new('DOLLYPARTON')
    # allow(client1).to receive(:get).and_return(user1_fake_types)
    #client2 = Lighthouse::LettersGenerator::Client.new('THEHONORS')

    # expect(client1).to receive(:get).and_return(user1_fake_types)
    # expect(client2).to receive(:get).and_return(user2_fake_types)

    user1_actual_types = client1.get_eligible_letter_types
    # user2_actual_types = client2.get_eligible_letter_types

    expect(client1).to have_received(:get)
    expect(user1_actual_types).to eq(user1_fake_types)
    # expect(user2_actual_types).to eq(user2_fake_types)
  end
end