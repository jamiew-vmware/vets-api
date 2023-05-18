# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BankName, type: :model do
  let(:bank_name_redis) { described_class.new(routing_number:, bank_name:) }
  let(:routing_number) { 'some-routing-number' }
  let(:bank_name) { 'some-bank-name' }

  describe 'validations' do
    context 'when routing number is nil' do
      let(:routing_number) { nil }
      let(:expected_error) { Common::Exceptions::ValidationErrors }

      it 'returns validation error' do
        expect { bank_name_redis.save! }.to raise_exception(expected_error)
      end
    end

    context 'when bank name is nil' do
      let(:bank_name) { nil }
      let(:expected_error) { Common::Exceptions::ValidationErrors }

      it 'returns validation error' do
        expect { bank_name_redis.save! }.to raise_exception(expected_error)
      end
    end
  end
end
