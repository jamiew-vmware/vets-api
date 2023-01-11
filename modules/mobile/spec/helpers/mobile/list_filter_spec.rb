# frozen_string_literal: true

require 'rails_helper'

class Pet < Common::Base
  attribute :species, String
  attribute :age, Integer
  attribute :fully_vaccinated, Boolean
end

describe Mobile::ListFilter, aggregate_failures: true do
  let(:dog) do
    Pet.new(species: 'dog', age: 5, fully_vaccinated: true)
  end
  let(:puppy) do
    Pet.new(species: 'dog', age: 1, fully_vaccinated: false)
  end
  let(:cat) do
    Pet.new(species: 'cat', age: 12, fully_vaccinated: true)
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

      results, errors = Mobile::ListFilter.matches(list, params)
      expect(results).to eq([dog, puppy])
    end

    it 'excludes non-matches with the notEq operator' do
      filters = { species: { notEq: 'dog' } }
      params = paramiterize(filters)

      results, errors = Mobile::ListFilter.matches(list, params)
      expect(results).to eq([cat])
    end

    it 'handles multiple filters' do
      filters = { species: { eq: 'dog' }, age: { notEq: 5 } }
      params = paramiterize(filters)

      results, errors = Mobile::ListFilter.matches(list, params)
      expect(results).to eq([puppy])
    end

    it 'matches non-string attributes' do
      filters = { age: { eq: 1 }, fully_vaccinated: { eq: false } }
      params = paramiterize(filters)

      results, errors = Mobile::ListFilter.matches(list, params)
      expect(results).to eq([puppy])
    end

    it 'returns a collection with an empty array of data when no matches are found' do
      filters = { species: { eq: 'turtle' } }
      params = paramiterize(filters)

      results, errors = Mobile::ListFilter.matches(list, params)
      expect(results.class).to eq(Array)
      expect(results).to eq([])
    end

    it 'returns the collection when empty filters are provided' do
      params = paramiterize({})

      results, errors = Mobile::ListFilter.matches(list, params)
      expect(results).to eq(list)
    end

    describe 'data validation and error handling' do
      before do
        Settings.sentry.dsn = 'asdf'
      end

      after do
        Settings.sentry.dsn = nil
      end

      # it 'logs an error and returns original collection when collection is not a Common::Collection' do
      #   params = paramiterize({})

      #   expect(Raven).to receive(:capture_exception).once.with(Mobile::ListFilter::FilterError, { level: 'error' })
      #   expect(Raven).to receive(:extra_context).with({ filters: params.to_unsafe_hash })
      #   result, errors = Mobile::ListFilter.matches([], params)
      #   expect(result).to eq([])
      # end

      it 'logs an error and returns original collection when filters are not an ActionController::Params object' do
        expect(Raven).to receive(:capture_exception).once.with(Mobile::ListFilter::FilterError, { level: 'error' })
        expect(Raven).to receive(:extra_context).with({ list_models: ['Pet'] })
        result, errors = Mobile::ListFilter.matches(list, {})
        expect(result).to eq(list)
        expect(errors).to eq({ filter_error: 'filters must be an ActionController::Parameters' })
      end

      it 'logs an error and returns original collection when collection contains mixed models' do
        params = paramiterize({})
        mixed_list = [dog, 'string']

        expect(Raven).to receive(:capture_exception).once.with(Mobile::ListFilter::FilterError, { level: 'error' })
        expect(Raven).to receive(:extra_context).with(
          { filters: params.to_unsafe_hash, list_models: %w[Pet String] }
        )
        result, errors = Mobile::ListFilter.matches(mixed_list, params)
        expect(result).to eq(mixed_list)
        expect(errors).to eq({ filter_error: 'list contains multiple models' })
      end

      it 'logs an error and returns original collection when the model does contain the requested filter attribute' do
        params = paramiterize({ genus: { eq: 'dog' } })

        expect(Raven).to receive(:capture_exception).once.with(Mobile::ListFilter::FilterError, { level: 'error' })
        expect(Raven).to receive(:extra_context).with({ filters: params.to_unsafe_hash, list_models: ['Pet'] })
        result, errors = Mobile::ListFilter.matches(list, params)
        expect(result).to eq(list)
        expect(errors).to eq({ filter_error: 'invalid attribute' })
      end

      it 'logs an error and returns original collection when the filter is not a hash' do
        params = ActionController::Parameters.new({ genus: 'dog' })

        expect(Raven).to receive(:capture_exception).once.with(Mobile::ListFilter::FilterError, { level: 'error' })
        expect(Raven).to receive(:extra_context).with({ filters: params.to_unsafe_hash, list_models: ['Pet'] })
        result, errors = Mobile::ListFilter.matches(list, params)
        expect(result).to eq(list)
        expect(errors).to eq({ filter_error: 'invalid filter structure' })
      end

      it 'logs an error and returns original collection when the filter contains multiple operations' do
        params = paramiterize({ genus: { eq: 'dog', notEq: 'cat' } })

        expect(Raven).to receive(:capture_exception).once.with(Mobile::ListFilter::FilterError, { level: 'error' })
        expect(Raven).to receive(:extra_context).with({ filters: params.to_unsafe_hash, list_models: ['Pet'] })
        result, errors = Mobile::ListFilter.matches(list, params)
        expect(result).to eq(list)
        expect(errors).to eq({ filter_error: 'invalid filter structure' })
      end

      it 'logs an error and returns original collection when the requested filter operation is not supported' do
        params = paramiterize({ species: { fuzzyEq: 'dog' } })

        expect(Raven).to receive(:capture_exception).once.with(Mobile::ListFilter::FilterError, { level: 'error' })
        expect(Raven).to receive(:extra_context).with({ filters: params.to_unsafe_hash, list_models: ['Pet'] })
        result, errors = Mobile::ListFilter.matches(list, params)
        expect(result).to eq(list)
        expect(errors).to eq({ filter_error: 'invalid operation' })
      end

      it 'logs an error and returns collection when an unexpected error occurs' do
        params = paramiterize({})
        allow_any_instance_of(Mobile::ListFilter).to receive(:matches).and_raise(StandardError)

        expect(Raven).to receive(:capture_exception).once.with(StandardError, { level: 'error' })
        expect(Raven).to receive(:extra_context).with({ filters: params.to_unsafe_hash, list_models: ['Pet'] })
        result, errors = Mobile::ListFilter.matches(list, params)
        expect(result).to eq(list)
        expect(errors).to eq({ filter_error: 'unknown filter error' })
      end
    end
  end
end
