# frozen_string_literal: true

require 'rails_helper'

describe Mobile::AppointmentsCacheInterface do
  let(:subject) { described_class.new }
  let(:user) { build(:user) }
  let(:today) { '2020-11-01T10:30:00Z' }
  # setting cache to empty array is sufficient for testing the "cache is set" behavior
  let(:cached_data) { [] }
  let(:mocked_appointments) { %i[appt1 appt2] }

  def set_cache
    Mobile::V0::Appointment.set_cached(user, cached_data)
  end

  describe '#fetch_appointments' do
    describe 'cache fetching' do
      context 'when fetch_cache is true' do
        context 'and cache is set' do
          before { set_cache }

          it 'fetches data from the cache and does not request from upstream' do
            expect(Mobile::V0::Appointment).to receive(:get_cached).and_call_original
            expect(Mobile::V2::Appointments::Proxy).not_to receive(:new)
            subject.fetch_appointments(user: user, fetch_cache: true)
          end
        end

        context 'and cache is not set' do
          it 'attempts to fetch from the cache, then falls back to upstream request' do
            expect(Mobile::V0::Appointment).to receive(:get_cached).and_call_original
            expect_any_instance_of(Mobile::V2::Appointments::Proxy).to receive(:get_appointments)
            subject.fetch_appointments(user: user, fetch_cache: true)
          end
        end
      end

      context 'when fetch_cache is false' do
        it 'does not attempt to fetch from the cache and instead makes an upstream request' do
          expect(Mobile::V0::Appointment).not_to receive(:get_cached)
          expect_any_instance_of(Mobile::V2::Appointments::Proxy).to receive(:get_appointments)
          subject.fetch_appointments(user: user, fetch_cache: false)
        end
      end

      context 'when fetch_cache is omitted' do
        it 'attempts to fetch from the cache, then falls back to upstream request' do
          expect(Mobile::V0::Appointment).to receive(:get_cached).and_call_original
          expect_any_instance_of(Mobile::V2::Appointments::Proxy).to receive(:get_appointments)
          subject.fetch_appointments(user: user)
        end
      end
    end

    describe 'cache setting' do
      it 'does not set cache when data was successfully fetched from cache' do
        set_cache
        expect(Mobile::V0::Appointment).not_to receive(:set_cached)
        subject.fetch_appointments(user: user, fetch_cache: true)
      end

      it 'sets cache when fetching fresh data from upstream' do
        allow_any_instance_of(Mobile::V2::Appointments::Proxy).to \
          receive(:get_appointments).and_return(mocked_appointments)
        expect(Mobile::V0::Appointment).to receive(:set_cached).with(user, mocked_appointments)
        subject.fetch_appointments(user: user, fetch_cache: true)
      end
    end

    context 'when mobile_appointment_use_VAOS_v2 flag is enabled' do
      before { Flipper.enable(:mobile_appointment_use_VAOS_v2) }

      it 'returns data found in the cache when cache is set and fetch_cache is true' do
        set_cache
        expect(
          subject.fetch_appointments(user: user, fetch_cache: true)
        ).to eq(cached_data)
      end

      it 'returns appointments from the V2 server when cache is not set' do
        expect_any_instance_of(Mobile::V2::Appointments::Proxy).to \
          receive(:get_appointments).and_return(mocked_appointments)
        expect(subject.fetch_appointments(user: user)).to eq(mocked_appointments)
      end

      it 'uses default start and end dates when not provided' do
        expect_any_instance_of(Mobile::V2::Appointments::Proxy).to receive(:get_appointments).with(
          start_date: subject.latest_allowable_cache_start_date,
          end_date: subject.earliest_allowable_cache_end_date,
          include_pending: true
        )
        subject.fetch_appointments(user: user)
      end

      it 'uses provided start and end dates when they are further from the current date than the defaults' do
        query_start_date = DateTime.now.utc - 2.years
        query_end_date = DateTime.now.utc + 2.years

        expect_any_instance_of(Mobile::V2::Appointments::Proxy).to receive(:get_appointments).with(
          start_date: query_start_date, end_date: query_end_date, include_pending: true
        )
        subject.fetch_appointments(user: user, start_date: query_start_date, end_date: query_end_date)
      end

      it 'uses default start and end dates provided dates are too close to current date' do
        query_start_date = DateTime.now.utc - 1.day
        query_end_date = DateTime.now.utc + 1.day

        expect_any_instance_of(Mobile::V2::Appointments::Proxy).to receive(:get_appointments).with(
          start_date: subject.latest_allowable_cache_start_date,
          end_date: subject.earliest_allowable_cache_end_date,
          include_pending: true
        )
        subject.fetch_appointments(user: user, start_date: query_start_date, end_date: query_end_date)
      end
    end

    context 'when mobile_appointment_use_VAOS_v2 flag is disabled' do
      let(:klass_double) { double('Mobile::V0::Appointments::Proxy') }

      before do
        Flipper.disable(:mobile_appointment_use_VAOS_v2)
        # can't stub this with any_instance_of because the class is extended in the statsd initializer
        allow(Mobile::V0::Appointments::Proxy).to receive(:new).and_return(klass_double)
      end

      after { Flipper.enable(:mobile_appointment_use_VAOS_v2) }

      it 'returns data found in the cache when cache is set and fetch_cache is true' do
        set_cache
        expect(
          subject.fetch_appointments(user: user, fetch_cache: true)
        ).to eq(cached_data)
      end

      it 'returns appointments from the V0 server' do
        expect(klass_double).to receive(:get_appointments).and_return(mocked_appointments)
        expect(subject.fetch_appointments(user: user)).to eq(mocked_appointments)
      end

      it 'uses default start and end dates when not provided' do
        expect(klass_double).to receive(:get_appointments).with(
          start_date: subject.latest_allowable_cache_start_date,
          end_date: subject.earliest_allowable_cache_end_date
        )
        subject.fetch_appointments(user: user)
      end

      it 'uses provided start and end dates when they are further from the current date than the defaults' do
        query_start_date = DateTime.now.utc - 2.years
        query_end_date = DateTime.now.utc + 2.years

        expect(klass_double).to receive(:get_appointments).with(start_date: query_start_date, end_date: query_end_date)
        subject.fetch_appointments(user: user, start_date: query_start_date, end_date: query_end_date)
      end

      it 'uses default start and end dates provided dates are too close to current date' do
        query_start_date = DateTime.now.utc - 1.day
        query_end_date = DateTime.now.utc + 1.day

        expect(klass_double).to receive(:get_appointments).with(
          start_date: subject.latest_allowable_cache_start_date,
          end_date: subject.earliest_allowable_cache_end_date
        )
        subject.fetch_appointments(user: user, start_date: query_start_date, end_date: query_end_date)
      end
    end
  end

  describe '#latest_allowable_cache_start_date' do
    before { Timecop.freeze(Time.zone.parse(today)) }

    after { Timecop.return }

    it 'is set to the beginning of last year' do
      expect(subject.latest_allowable_cache_start_date).to eq(today.to_datetime.utc.beginning_of_year - 1.year)
    end
  end

  describe '#earliest_allowable_cache_end_date' do
    before { Timecop.freeze(Time.zone.parse(today)) }

    after { Timecop.return }

    it 'is set to one year from today' do
      expect(subject.earliest_allowable_cache_end_date).to eq(today.to_datetime.utc.beginning_of_day + 1.year)
    end
  end
end