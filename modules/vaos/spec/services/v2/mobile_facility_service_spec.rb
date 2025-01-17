# frozen_string_literal: true

require 'rails_helper'

describe VAOS::V2::MobileFacilityService do
  subject { described_class.new(user) }

  let(:user) { build(:user, :vaos) }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

  before do
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
    allow(Rails).to receive(:cache).and_return(memory_store)
    Rails.cache.clear
  end

  describe '#configuration' do
    context 'with a single facility id arg' do
      it 'returns a scheduling configuration' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_scheduling_configurations_200',
                         match_requests_on: %i[method path query], tag: :force_utf8) do
          response = subject.get_scheduling_configurations('489')
          expect(response[:data].size).to eq(1)
        end
      end
    end

    context 'with multiple facility ids arg' do
      it 'returns scheduling configurations' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_scheduling_configurations_200',
                         match_requests_on: %i[method path query], tag: :force_utf8) do
          response = subject.get_scheduling_configurations('489,984')
          expect(response[:data].size).to eq(2)
        end
      end
    end

    context 'with multiple facility ids and cc enabled args' do
      it 'returns scheduling configuration' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_scheduling_configurations_cc_200',
                         match_requests_on: %i[method path query], tag: :force_utf8) do
          response = subject.get_scheduling_configurations('489,984', true)
          expect(response[:data].size).to eq(1)
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_scheduling_configurations_500',
                         match_requests_on: %i[method path query]) do
          expect { subject.get_scheduling_configurations(489, false) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end

  describe '#facilities' do
    context 'with a facility id' do
      it 'returns a configuration' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_facilities_single_id_200',
                         match_requests_on: %i[method path query]) do
          response = subject.get_facilities(ids: '688')
          expect(response[:data].size).to eq(1)
        end
      end
    end

    context 'with multiple facility ids' do
      it 'returns a configuration' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_facilities_200',
                         match_requests_on: %i[method path query]) do
          response = subject.get_facilities(ids: '983,984')
          expect(response[:data].size).to eq(2)
        end
      end
    end

    context 'with a facility id and children true' do
      it 'returns a configuration' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_facilities_with_children_200',
                         match_requests_on: %i[method path query]) do
          response = subject.get_facilities(children: true, ids: '688')
          expect(response[:data].size).to eq(8)
        end
      end
    end

    context 'when the upstream server returns a 400' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_facilities_400',
                         match_requests_on: %i[method path query]) do
          expect { subject.get_facilities(ids: 688) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_facilities_500',
                         match_requests_on: %i[method path query]) do
          expect { subject.get_facilities(ids: '688') }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end

  describe '#get_clinic' do
    context 'with a valid request and station is a parent VHA facility' do
      it 'returns the clinic information' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_clinic_200',
                         match_requests_on: %i[method path query]) do
          clinic = subject.get_clinic(station_id: '983', clinic_id: '455')
          expect(clinic[:station_id]).to eq('983')
          expect(clinic[:clinic_id]).to eq('455')
        end
      end
    end

    context 'with a valid request and station is not a parent VHA facility' do
      it 'returns the clinic information' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_clinic_200',
                         match_requests_on: %i[method path query]) do
          clinic = subject.get_clinic(station_id: '983GB', clinic_id: '1053')
          expect(clinic[:station_id]).to eq('983GB')
          expect(clinic[:clinic_id]).to eq('1053')
        end
      end
    end

    context 'with a non existing clinic' do
      it 'raises a BackendServiceException' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_clinic_500',
                         match_requests_on: %i[method path query]) do
          expect { subject.get_clinic(station_id: '983', clinic_id: 'does_not_exist') }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end

  describe '#get_clinic_with_cache' do
    context 'with a valid request and clinic is not in the cache' do
      it 'returns the clinic information and stores it in the cache' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_clinic_200',
                         match_requests_on: %i[method path query]) do
          expect(Rails.cache.exist?('vaos_clinic_983_455')).to eq(false)
          clinic = subject.get_clinic_with_cache(station_id: '983', clinic_id: '455')
          expect(clinic[:station_id]).to eq('983')
          expect(clinic[:clinic_id]).to eq('455')
          expect(Rails.cache.exist?('vaos_clinic_983_455')).to eq(true)
        end
      end

      it "calls '#get_clinic' retrieving information from MFS" do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_clinic_200',
                         match_requests_on: %i[method path query]) do
          # rubocop:disable RSpec/SubjectStub
          expect(subject).to receive(:get_clinic).once.and_call_original
          # rubocop:enable RSpec/SubjectStub
          subject.get_clinic_with_cache(station_id: '983', clinic_id: '455')
          expect(Rails.cache.exist?('vaos_clinic_983_455')).to eq(true)
        end
      end
    end

    context 'with a valid request and the clinic is in the cache' do
      it 'returns the clinic information from the cache' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_clinic_200',
                         match_requests_on: %i[method path query]) do
          # prime the cache
          response = subject.get_clinic(station_id: '983', clinic_id: '455')
          Rails.cache.write('vaos_clinic_983_455', response)

          # rubocop:disable RSpec/SubjectStub
          expect(subject).not_to receive(:get_clinic)
          # rubocop:enable RSpec/SubjectStub
          cached_response = subject.get_clinic_with_cache(station_id: '983', clinic_id: '455')
          expect(response).to eq(cached_response)
          expect(Rails.cache.exist?('vaos_clinic_983_455')).to eq(true)
        end
      end
    end

    context 'with a backend server error' do
      it 'raises a BackendServiceException and nothing is cached' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_clinic_500',
                         match_requests_on: %i[method path query]) do
          expect { subject.get_clinic_with_cache(station_id: '983', clinic_id: 'does_not_exist') }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
          expect(Rails.cache.exist?('vaos_clinic_983_does_not_exist')).to eq(false)
        end
      end
    end
  end

  describe '#get_facility' do
    context 'with a valid request' do
      it 'returns a facility' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_facility_200',
                         match_requests_on: %i[method path query]) do
          response = subject.get_facility('983')
          expect(response[:id]).to eq('983')
          expect(response[:type]).to eq('va_facilities')
          expect(response[:name]).to eq('Cheyenne VA Medical Center')
        end
      end
    end

    context 'when the upstream server returns a 400' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_facility_400',
                         match_requests_on: %i[method path query]) do
          expect { subject.get_facility('983') }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_facility_500',
                         match_requests_on: %i[method path query]) do
          expect { subject.get_facility('983') }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end

  describe '#get_facility_with_cache' do
    context 'with a valid request and facility is not in the cache' do
      it 'retrieves the facility from MFS and stores the facility in the cache' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_facility_200',
                         match_requests_on: %i[method path query]) do
          expect(Rails.cache.exist?('vaos_facility_983')).to eq(false)

          response = subject.get_facility_with_cache('983')

          expect(response[:id]).to eq('983')
          expect(response[:type]).to eq('va_facilities')
          expect(response[:name]).to eq('Cheyenne VA Medical Center')
          expect(Rails.cache.exist?('vaos_facility_983')).to eq(true)
        end
      end
    end

    it 'calls #get_facility' do
      VCR.use_cassette('vaos/v2/mobile_facility_service/get_facility_200',
                       match_requests_on: %i[method path query]) do
        # rubocop:disable RSpec/SubjectStub
        expect(subject).to receive(:get_facility).once.and_call_original
        # rubocop:enable RSpec/SubjectStub
        subject.get_facility_with_cache('983')
      end
    end

    context 'with a valid request and facility is in the cache' do
      it 'returns the facility from the cache' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_facility_200',
                         match_requests_on: %i[method path query]) do
          # prime the cache
          response = subject.get_facility('983')
          Rails.cache.write('vaos_facility_983', response)

          # rubocop:disable RSpec/SubjectStub
          expect(subject).not_to receive(:get_facility)
          # rubocop:enable RSpec/SubjectStub
          cached_response = subject.get_facility_with_cache('983')
          expect(response).to eq(cached_response)
          expect(Rails.cache.exist?('vaos_facility_983')).to eq(true)
        end
      end
    end

    context 'with a backend server error' do
      it 'raises a backend exception and nothing is cached' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_facility_500',
                         match_requests_on: %i[method path query]) do
          expect { subject.get_facility_with_cache('983') }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
          expect(Rails.cache.exist?('vaos_facility_983')).to eq(false)
        end
      end
    end
  end
end
