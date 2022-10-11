# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      # Due to backwards compatibility requirements, this adapter takes in VAOS V2
      # schema and outputs Mobile V0 appointments. Eventually this will be rolled
      # off in favor of Mobile Appointment V2 model.
      #
      # @example create a new instance and parse incoming data
      #   Mobile::V0::Adapters::VAOSV2Appointments.new.parse(appointments)
      #
      class VAOSV2Appointments
        APPOINTMENT_TYPES = {
          va: 'VA',
          cc: 'COMMUNITY_CARE',
          va_video_connect_home: 'VA_VIDEO_CONNECT_HOME',
          va_video_connect_gfe: 'VA_VIDEO_CONNECT_GFE',
          va_video_connect_atlas: 'VA_VIDEO_CONNECT_ATLAS'
        }.freeze

        HIDDEN_STATUS = %w[
          noshow
          pending
        ].freeze

        STATUSES = {
          booked: 'BOOKED',
          fulfilled: 'BOOKED',
          arrived: 'BOOKED',
          cancelled: 'CANCELLED',
          hidden: 'HIDDEN',
          proposed: 'SUBMITTED'
        }.freeze

        CANCELLATION_REASON = {
          pat: 'CANCELLED BY PATIENT',
          prov: 'CANCELLED BY CLINIC'
        }.freeze

        CONTACT_TYPE = {
          phone: 'phone',
          email: 'email'
        }.freeze

        VIDEO_GFE_CODE = 'MOBILE_GFE'
        PHONE_KIND = 'phone'
        COVID_SERVICE = 'covid'

        # Only a subset of types of service that requires human readable conversion
        SERVICE_TYPES = {
          outpatientMentalHealth: 'Mental Health',
          moveProgram: 'Move Program',
          foodAndNutrition: 'Nutrition and Food',
          clinicalPharmacyPrimaryCare: 'Clinical Pharmacy Primary Care',
          primaryCare: 'Primary Care',
          homeSleepTesting: 'Home Sleep Testing',
          socialWork: 'Social Work'
        }.freeze

        # Takes a result set of VAOS v2 appointments from the appointments web service
        # and returns the set adapted to a common schema.
        #
        # @appointments Hash a list of variousappointment types
        #
        # @return Hash the adapted list
        #
        def parse(appointments = [])
          appointments.map do |appointment_hash|
            build_appointment_model(appointment_hash)
          rescue => e
            Rails.logger.error(
              'Error adapting VAOS v2 appointment into Mobile V0 appointment',
              appointment: appointment_hash, error: e.message, backtrace: e.backtrace
            )
            next
          end.compact
        end

        private

        # rubocop:disable Metrics/MethodLength
        def build_appointment_model(appointment_hash)
          facility_id = Mobile::V0::Appointment.convert_from_non_prod_id!(
            appointment_hash[:location_id]
          )
          sta6aid = facility_id
          type = map_appointment_type(appointment_hash, appointment_hash[:kind])
          start_date_utc = start_date_utc(appointment_hash)
          time_zone = timezone(appointment_hash, facility_id)
          start_date_local = start_date_utc&.in_time_zone(time_zone)
          status = status(appointment_hash)
          location = location(type, appointment_hash)
          adapted_hash = {
            id: appointment_hash[:id],
            appointment_type: type,
            cancel_id: cancel_id(appointment_hash),
            comment: appointment_hash[:comment] || appointment_hash.dig(:reason_code, :text),
            facility_id: facility_id,
            sta6aid: sta6aid,
            healthcare_provider: appointment_hash[:healthcare_provider],
            healthcare_service: healthcare_service(appointment_hash, type),
            location: location,
            minutes_duration: minutes_duration(appointment_hash[:minutes_duration], type),
            phone_only: appointment_hash[:kind] == PHONE_KIND,
            start_date_local: start_date_local,
            start_date_utc: start_date_utc,
            status: status,
            status_detail: cancellation_reason(appointment_hash[:cancelation_reason]),
            time_zone: time_zone,
            vetext_id: nil,
            reason: appointment_hash.dig(:reason_code, :coding, 0, :code),
            is_covid_vaccine: appointment_hash[:service_type] == COVID_SERVICE,
            is_pending: appointment_hash[:requested_periods].present?,
            proposed_times: proposed_times(appointment_hash[:requested_periods]),
            type_of_care: type_of_care(appointment_hash[:service_type]),
            patient_phone_number: patient_phone_number(appointment_hash),
            patient_email: contact(appointment_hash.dig(:contact, :telecom), CONTACT_TYPE[:email]),
            best_time_to_call: appointment_hash[:preferred_times_for_phone_call],
            friendly_location_name: friendly_location_name(type, appointment_hash, location)
          }

          Rails.logger.info('metric.mobile.appointment.type', type: type)
          Rails.logger.info('metric.mobile.appointment.upstream_status', status: appointment_hash[:status])

          Mobile::V0::Appointment.new(adapted_hash)
        end
        # rubocop:enable Metrics/MethodLength

        def friendly_location_name(type, appointment_hash, location)
          return location[:name] if va?(type)

          appointment_hash.dig(:extension, :cc_location, :practice_name)
        end

        def patient_phone_number(appointment_hash)
          phone_number = contact(appointment_hash.dig(:contact, :telecom), CONTACT_TYPE[:phone])

          return nil unless phone_number

          parsed_phone = parse_phone(phone_number)
          joined_phone = "#{parsed_phone[:area_code]}-#{parsed_phone[:number]}"
          joined_phone += "x#{parsed_phone[:extension]}" if parsed_phone[:extension]
          joined_phone
        end

        def timezone(appointment_hash, facility_id)
          time_zone = appointment_hash.dig(:location, :time_zone, :time_zone_id)
          return time_zone if time_zone

          return nil unless facility_id

          # not always correct if clinic is different time zone than parent
          facility = Mobile::VA_FACILITIES_BY_ID["dfn-#{facility_id[0..2]}"]
          facility ? facility[:time_zone] : nil
        end

        def cancel_id(appointment_hash)
          return nil unless appointment_hash[:cancellable]

          appointment_hash[:id]
        end

        def type_of_care(service_type)
          return nil if service_type.nil?

          service_type = SERVICE_TYPES[service_type.to_sym] || service_type

          service_type.titleize
        end

        def cancellation_reason(cancellation_reason)
          return nil if cancellation_reason.nil?

          cancel_code = cancellation_reason.dig(:coding, 0, :code)
          CANCELLATION_REASON[cancel_code&.to_sym]
        end

        def contact(telecom, type)
          return nil if telecom.blank?

          telecom.select { |contact| contact[:type] == type }&.dig(0, :value)
        end

        def proposed_times(requested_periods)
          return nil if requested_periods.nil?

          requested_periods.map do |period|
            start_date = DateTime.parse(period[:start])
            {
              date: start_date.strftime('%m/%d/%Y'),
              time: start_date.hour.zero? ? 'AM' : 'PM'
            }
          end
        end

        def status(appointment_hash)
          return STATUSES[:hidden] if HIDDEN_STATUS.include?(appointment_hash[:status])

          STATUSES[appointment_hash[:status].to_sym]
        end

        def start_date_utc(appointment_hash)
          start = appointment_hash[:start]
          if start.nil?
            sorted_dates = appointment_hash[:requested_periods].map { |period| DateTime.parse(period[:start]) }.sort
            future_dates = sorted_dates.select { |period| period > DateTime.now }
            future_dates.any? ? future_dates.first : sorted_dates.first
          else
            DateTime.parse(start)
          end
        end

        def map_appointment_type(appointment_hash, type)
          case type
          when 'phone', 'clinic'
            APPOINTMENT_TYPES[:va]
          when 'cc'
            APPOINTMENT_TYPES[:cc]
          when 'telehealth'
            if appointment_hash.dig(:telehealth, :vvs_kind) == VIDEO_GFE_CODE
              APPOINTMENT_TYPES[:va_video_connect_gfe]
            elsif appointment_hash.dig(:telehealth, :atlas)
              APPOINTMENT_TYPES[:va_video_connect_atlas]
            else
              APPOINTMENT_TYPES[:va_video_connect_home]
            end
          else
            APPOINTMENT_TYPES[:va]
          end
        end

        # rubocop:disable Metrics/MethodLength
        def location(type, appointment_hash)
          location = {
            id: nil,
            name: nil,
            address: {
              street: nil,
              city: nil,
              state: nil,
              zip_code: nil
            },
            lat: nil,
            long: nil,
            phone: {
              area_code: nil,
              number: nil,
              extension: nil
            },
            url: nil,
            code: nil
          }
          telehealth = appointment_hash[:telehealth]

          case type
          when APPOINTMENT_TYPES[:cc]
            cc_location = appointment_hash.dig(:extension, :cc_location)

            if cc_location.present?
              location[:name] = cc_location[:practice_name]
              location[:address] = {
                street: cc_location.dig(:address, :line)&.join(' ')&.strip,
                city: cc_location.dig(:address, :city),
                state: cc_location.dig(:address, :state),
                zip_code: cc_location.dig(:address, :postal_code)
              }
              if cc_location[:telecom].present?
                phone_number = cc_location[:telecom]&.find do |contact|
                  contact[:system] == CONTACT_TYPE[:phone]
                end&.dig(:value)

                location[:phone] = parse_phone(phone_number)
              end

            end
          when APPOINTMENT_TYPES[:va_video_connect_atlas],
            APPOINTMENT_TYPES[:va_video_connect_home],
            APPOINTMENT_TYPES[:va_video_connect_gfe]

            location[:name] = appointment_hash.dig(:location, :name)

            if telehealth
              address = telehealth.dig(:atlas, :address)

              if address
                location[:address] = {
                  street: address[:street_address],
                  city: address[:city],
                  state: address[:state],
                  zip_code: address[:zip_code],
                  country: address[:country]
                }
              end

              location[:url] = telehealth[:url]
              location[:code] = telehealth.dig(:atlas, :confirmation_code)
            end
          else
            location[:id] = appointment_hash.dig(:location, :id)
            location[:name] = appointment_hash.dig(:location, :name)
            address = appointment_hash.dig(:location, :physical_address)
            if address.present?
              location[:address] = {
                street: address[:line]&.join(' ')&.strip,
                city: address[:city],
                state: address[:state],
                zip_code: address[:postal_code]
              }
            end
            location[:lat] = appointment_hash.dig(:location, :lat)
            location[:long] = appointment_hash.dig(:location, :long)
            location[:phone] = parse_phone(appointment_hash.dig(:location, :phone, :main))
          end

          location
        end
        # rubocop:enable Metrics/MethodLength

        def parse_phone(phone)
          # captures area code (\d{3}) number (\d{3}-\d{4})
          # and optional extension (until the end of the string) (?:\sx(\d*))?$
          phone_captures = phone&.match(/^\(?(\d{3})\)?.?(\d{3})-?(\d{4})(?:\sx(\d*))?$/)

          if phone_captures.nil?
            Rails.logger.warn(
              'mobile appointments failed to parse VAOS V2 phone number',
              phone: phone
            )
            return { area_code: nil, number: nil, extension: nil }
          end

          {
            area_code: phone_captures[1].presence,
            number: "#{phone_captures[2].presence}-#{phone_captures[3].presence}",
            extension: phone_captures[4].presence
          }
        end

        def healthcare_service(appointment_hash, type)
          if va?(type)
            appointment_hash[:service_name] || appointment_hash[:physical_location]
          else
            appointment_hash.dig(:extension, :cc_location, :practice_name)
          end
        end

        def minutes_duration(minutes_duration, type)
          # not in raw data, matches va.gov default for cc appointments
          return 60 if type == APPOINTMENT_TYPES[:cc] && minutes_duration.nil?

          minutes_duration
        end

        def va?(type)
          [APPOINTMENT_TYPES[:va],
           APPOINTMENT_TYPES[:va_video_connect_gfe],
           APPOINTMENT_TYPES[:va_video_connect_atlas],
           APPOINTMENT_TYPES[:va_video_connect_home]].include?(type)
        end
      end
    end
  end
end
