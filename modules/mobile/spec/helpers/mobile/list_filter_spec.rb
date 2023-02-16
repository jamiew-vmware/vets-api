# frozen_string_literal: true

require 'rails_helper'
require 'common/models/resource'

class PetBase < Common::Base
  attribute :species, String
  attribute :age, Integer
  attribute :fully_vaccinated, Boolean
end

class PetResource < Common::Resource
  attribute :species, Types::String
  attribute :age, Types::Integer
  attribute :fully_vaccinated, Types::Bool.optional
end

describe Mobile::ListFilter, aggregate_failures: true do
  let(:dog) do
    PetResource.new(species: 'dog', age: 5, fully_vaccinated: true)
  end
  let(:puppy) do
    PetResource.new(species: 'dog', age: 1, fully_vaccinated: false)
  end
  let(:cat) do
    PetResource.new(species: 'cat', age: 12, fully_vaccinated: nil)
  end
  let(:list) do
    [dog, puppy, cat]
  end

  def paramiterize(params)
    # ensuring param values are strings because they will always be strings when coming from controllers
    params.each_pair do |key, operation_value_pair|
      operation_value_pair.each { |operation, value| params[key][operation] = value.to_s }
    end
    ActionController::Parameters.new(params)
  end

  describe '.matches' do
    it 'finds matches with the eq operator' do
      filters = { species: { eq: 'dog' } }
      params = paramiterize(filters)

      result = Mobile::ListFilter.matches(list, params)
      expect(result).to eq([dog, puppy])
    end

    it 'excludes non-matches with the not_eq operator' do
      filters = { species: { not_eq: 'dog' } }
      params = paramiterize(filters)

      result = Mobile::ListFilter.matches(list, params)
      expect(result).to eq([cat])
    end

    it 'handles multiple filters' do
      filters = { species: { eq: 'dog' }, age: { not_eq: 5 } }
      params = paramiterize(filters)

      result = Mobile::ListFilter.matches(list, params)
      expect(result).to eq([puppy])
    end

    it 'matches non-string attributes' do
      filters = { age: { eq: 1 }, fully_vaccinated: { eq: false } }
      params = paramiterize(filters)

      result = Mobile::ListFilter.matches(list, params)
      expect(result).to eq([puppy])
    end

    it 'returns a list with an empty array of data when no matches are found' do
      filters = { species: { eq: 'turtle' } }
      params = paramiterize(filters)

      result = Mobile::ListFilter.matches(list, params)
      expect(result).to eq([])
    end

    it 'returns the list when empty filters are provided' do
      params = paramiterize({})

      result = Mobile::ListFilter.matches(list, params)
      expect(result).to eq(list)
    end

    describe 'data validation and error handling' do
      before do
        Settings.sentry.dsn = 'asdf'
      end

      after do
        Settings.sentry.dsn = nil
      end

      it 'works with an array of Common::Resource objects' do
        filters = { species: { eq: 'dog' } }
        params = paramiterize(filters)

        result = Mobile::ListFilter.matches(list, params)
        expect(result).to eq([dog, puppy])
      end

      it 'works with an array of Common::Base objects' do
        filters = { species: { eq: 'dog' } }
        params = paramiterize(filters)
        base_pup = PetBase.new(species: 'dog', age: 1, fully_vaccinated: false)
        base_dog = PetBase.new(species: 'dog', age: 5, fully_vaccinated: true)
        base_cat = PetBase.new(species: 'cat', age: 12, fully_vaccinated: nil)
        base_list = [base_pup, base_dog, base_cat]

        result = Mobile::ListFilter.matches(base_list, params)
        expect(result).to eq([base_pup, base_dog])
      end

      it 'logs an error and returns original list when list is not an array' do
        params = paramiterize({})

        expect { Mobile::ListFilter.matches({}, params) }.to raise_error(described_class::MobileFilterError)
      end

      it 'logs an error and returns original list when filters are not an ActionController::Params object' do
        expect { Mobile::ListFilter.matches(list, {}) }.to raise_error(described_class::MobileFilterError)
        expect(result).to eq(list)
      end

      it 'logs an error and returns original list when list contains mixed models' do
        params = paramiterize({})
        mixed_list = [dog, 'string']

        expect { Mobile::ListFilter.matches(mixed_list, params) }.to raise_error(described_class::MobileFilterError)
      end

      it 'logs an error and returns original list when the list contains data types that are not Common::Base' do
        params = paramiterize({ genus: { eq: 'dog' } })
        invalid_list = [{ species: 'dog', age: 3, fully_vaccinated: true }]

        expect { Mobile::ListFilter.matches(invalid_list, params) }.to raise_error(described_class::MobileFilterError)
      end

      it 'logs an error and returns original list when the model does contain the requested filter attribute' do
        params = paramiterize({ genus: { eq: 'dog' } })

        expect { Mobile::ListFilter.matches(list, params) }.to raise_error(described_class::MobileFilterError)
      end

      it 'logs an error and returns original list when the filter is not a hash' do
        params = ActionController::Parameters.new({ genus: 'dog' })

        expect{ Mobile::ListFilter.matches(list, params) }.to raise_error(described_class::MobileFilterError)
      end

      it 'logs an error and returns original list when the filter contains multiple operations' do
        params = paramiterize({ genus: { eq: 'dog', not_eq: 'cat' } })

        expect{ Mobile::ListFilter.matches(list, params) }.to raise_error(described_class::MobileFilterError)
      end

      it 'logs an error and returns original list when the requested filter operation is not supported' do
        params = paramiterize({ species: { fuzzyEq: 'dog' } })

        expect { Mobile::ListFilter.matches(list, params) }.to raise_error(described_class::MobileFilterError)
      end

      it 'logs an error and returns list when an unexpected error occurs' do
        params = paramiterize({})
        allow_any_instance_of(Mobile::ListFilter).to receive(:matches).and_raise(StandardError)

        expect { Mobile::ListFilter.matches(list, params) }.to raise_error(described_class::MobileFilterError)
      end
    end
  end
end
