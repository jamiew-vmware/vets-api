# frozen_string_literal: true

require 'rails_helper'
require 'bgs/vnp_veteran'

RSpec.describe BGS::VnpVeteran do
  let(:user_object) { FactoryBot.create(:evss_user, :loa3) }
  let(:icn) { user_object.icn }
  let(:common_name) { user_object.common_name }
  let(:participant_id) { user_object.participant_id }
  let(:ssn) { user_object.ssn }
  let(:first_name) { user_object.first_name }
  let(:middle_name) { user_object.middle_name }
  let(:last_name) { user_object.last_name }
  let(:all_flows_payload) { FactoryBot.build(:form_686c_674_kitchen_sink) }

  before { Timecop.freeze }

  after { Timecop.return }

  describe '#create' do
    context 'married veteran' do
      it 'returns a VnpPersonAddressPhone object' do
        VCR.use_cassette('bgs/vnp_veteran/create') do
          vnp_veteran = BGS::VnpVeteran.new(
            proc_id: '3828241',
            payload: all_flows_payload,
            claim_type: '130DPNEBNADJ',
            icn:,
            common_name:,
            participant_id:,
            ssn:,
            first_name:,
            middle_name:,
            last_name:
          ).create

          expect(vnp_veteran).to eq(
            vnp_participant_id: '151031',
            first_name: 'WESLEY',
            last_name: 'FORD',
            vnp_participant_address_id: '117658',
            file_number: '796043735',
            address_line_one: '8200 Doby LN',
            address_line_two: nil,
            address_line_three: nil,
            address_country: 'USA',
            address_state_code: 'CA',
            address_city: 'Pasadena',
            address_zip_code: '21122',
            address_type: nil,
            mlty_postal_type_cd: nil,
            mlty_post_office_type_cd: nil,
            foreign_mail_code: nil,
            type: 'veteran',
            benefit_claim_type_end_product: '139',
            regional_office_number: '313',
            location_id: '343',
            net_worth_over_limit_ind: 'Y'
          )
        end
      end
    end

    context 'default location id' do
      it 'returns 347 when BGS::Service#find_regional_offices returns nil' do
        VCR.use_cassette('bgs/vnp_veteran/create') do
          expect_any_instance_of(BGS::Service).to receive(:find_regional_offices).and_return nil

          vnp_veteran = BGS::VnpVeteran.new(
            proc_id: '3828241',
            payload: all_flows_payload,
            claim_type: '130DPNEBNADJ',
            icn:,
            common_name:,
            participant_id:,
            ssn:,
            first_name:,
            middle_name:,
            last_name:
          ).create

          expect(vnp_veteran).to include(location_id: '347')
        end
      end

      it 'returns 347 when BGS::Service#get_regional_office_by_zip_code returns an invalid regional office' do
        VCR.use_cassette('bgs/vnp_veteran/create') do
          expect_any_instance_of(BGS::Service)
            .to receive(:get_regional_office_by_zip_code).and_return 'invalid regional office'

          vnp_veteran = BGS::VnpVeteran.new(
            proc_id: '3828241',
            payload: all_flows_payload,
            claim_type: '130DPNEBNADJ',
            icn:,
            common_name:,
            participant_id:,
            ssn:,
            first_name:,
            middle_name:,
            last_name:
          ).create

          expect(vnp_veteran).to include(location_id: '347')
        end
      end
    end

    it 'calls BGS::Service: #create_person, #create_phone, and #create_address' do
      vet_person_hash = {
        person_params: {
          vnp_proc_id: '12345',
          vnp_ptcpnt_id: '151031',
          first_nm: 'WESLEY',
          middle_nm: nil,
          last_nm: 'FORD',
          suffix_nm: nil,
          birth_state_cd: nil,
          birth_city_nm: nil,
          birth_cntry_nm: nil,
          vnp_srusly_dsabld_ind: nil,
          brthdy_dt: '1809-02-12T12:00:00+00:00',
          file_nbr: '796043735',
          ssn_nbr: '796043735',
          death_dt: nil,
          ever_maried_ind: nil,
          vet_ind: 'Y',
          martl_status_type_cd: 'Separated'
        }
      }

      expected_address = {
        address_params: {
          addrs_one_txt: '2037400 twenty',
          addrs_two_txt: 'ninth St apt 2222',
          addrs_three_txt: 'Bldg 33333',
          city_nm: 'Pasadena',
          cntry_nm: 'USA',
          efctv_dt: Time.current.iso8601,
          email_addrs_txt: 'foo@foo.com',
          frgn_postal_cd: nil,
          mlty_post_office_type_cd: nil,
          mlty_postal_type_cd: nil,
          postal_cd: 'CA',
          prvnc_nm: 'CA',
          ptcpnt_addrs_type_nm: 'Mailing',
          shared_addrs_ind: 'N',
          vnp_proc_id: '12345',
          vnp_ptcpnt_id: '151031',
          zip_prefix_nbr: '21122'
        }
      }
      VCR.use_cassette('bgs/vnp_veteran/create') do
        expect_any_instance_of(BGS::Service).to receive(:create_person)
          .with(a_hash_including(vet_person_hash))
          .and_call_original

        expect_any_instance_of(BGS::Service).to receive(:create_phone)
          .with(proc_id: '12345', participant_id: '151031', phone_number: '1112223333')
          .and_call_original

        expect_any_instance_of(BGS::Service).to receive(:create_address)
          .with(a_hash_including(expected_address))
          .and_call_original

        BGS::VnpVeteran.new(
          proc_id: '12345',
          payload: all_flows_payload,
          claim_type: '130DPNEBNADJ',
          icn:,
          common_name:,
          participant_id:,
          ssn:,
          first_name:,
          middle_name:,
          last_name:
        ).create
      end
    end

    context 'SSN is not 9 digits' do
      let(:user_object) { FactoryBot.create(:evss_user, :loa3, ssn:) }
      let(:ssn) { '123456789' }
      let(:vet_person_hash) do
        {
          person_params: {
            vnp_proc_id: '3828241',
            vnp_ptcpnt_id: '151031',
            first_nm: 'WESLEY',
            middle_nm: nil,
            last_nm: 'FORD',
            suffix_nm: nil,
            birth_state_cd: nil,
            birth_city_nm: nil,
            birth_cntry_nm: nil,
            vnp_srusly_dsabld_ind: nil,
            brthdy_dt: '1809-02-12T12:00:00+00:00',
            file_nbr: '796043735',
            ssn_nbr: ssn,
            death_dt: nil,
            ever_maried_ind: nil,
            vet_ind: 'Y',
            martl_status_type_cd: 'Separated'
          }
        }
      end

      before { all_flows_payload['veteran_information']['ssn'] = '12345678' }

      it 'sets ssn to User#ssn' do
        VCR.use_cassette('bgs/vnp_veteran/create') do
          vnp_veteran = BGS::VnpVeteran.new(
            proc_id: '3828241',
            payload: all_flows_payload,
            claim_type: '130DPNEBNADJ',
            icn:,
            common_name:,
            participant_id:,
            ssn:,
            first_name:,
            middle_name:,
            last_name:
          )
          expect(vnp_veteran).not_to receive(:log_message_to_sentry)
          expect(Rails.logger).to receive(:info).with('Malformed SSN! Reassigning to User#ssn.')
          expect_any_instance_of(BGS::Service).to receive(:create_person).with(vet_person_hash)
          vnp_veteran.create
        end
      end

      context 'User#ssn returns the same invalid ssn' do
        let(:malformed_ssn) { '12345678' }
        let(:vet_person_hash) do
          {
            person_params: {
              vnp_proc_id: '3828241',
              vnp_ptcpnt_id: '151031',
              first_nm: 'WESLEY',
              middle_nm: nil,
              last_nm: 'FORD',
              suffix_nm: nil,
              birth_state_cd: nil,
              birth_city_nm: nil,
              birth_cntry_nm: nil,
              vnp_srusly_dsabld_ind: nil,
              brthdy_dt: '1809-02-12T12:00:00+00:00',
              file_nbr: '796043735',
              ssn_nbr: malformed_ssn,
              death_dt: nil,
              ever_maried_ind: nil,
              vet_ind: 'Y',
              martl_status_type_cd: 'Separated'
            }
          }
        end

        before { allow_any_instance_of(User).to receive(:ssn).and_return(malformed_ssn) }

        it 'logs an error to Sentry' do
          VCR.use_cassette('bgs/vnp_veteran/create') do
            vnp_veteran = BGS::VnpVeteran.new(
              proc_id: '3828241',
              payload: all_flows_payload,
              claim_type: '130DPNEBNADJ',
              icn:,
              common_name:,
              participant_id:,
              ssn: malformed_ssn,
              first_name:,
              middle_name:,
              last_name:
            )
            expect(Rails.logger).to receive(:info).with('Malformed SSN! Reassigning to User#ssn.')
            expect(vnp_veteran).to receive(:log_message_to_sentry).with(
              'SSN has 8 digits!',
              :error,
              {},
              { team: 'vfs-ebenefits' }
            )
            expect_any_instance_of(BGS::Service).to receive(:create_person).with(vet_person_hash)
            vnp_veteran.create
          end
        end
      end

      context 'User#ssn returns ********' do
        let(:malformed_ssn) { '********' }
        let(:vet_person_hash) do
          {
            person_params: {
              vnp_proc_id: '3828241',
              vnp_ptcpnt_id: '151031',
              first_nm: 'WESLEY',
              middle_nm: nil,
              last_nm: 'FORD',
              suffix_nm: nil,
              birth_state_cd: nil,
              birth_city_nm: nil,
              birth_cntry_nm: nil,
              vnp_srusly_dsabld_ind: nil,
              brthdy_dt: '1809-02-12T12:00:00+00:00',
              file_nbr: '796043735',
              ssn_nbr: malformed_ssn,
              death_dt: nil,
              ever_maried_ind: nil,
              vet_ind: 'Y',
              martl_status_type_cd: 'Separated'
            }
          }
        end

        before { allow_any_instance_of(User).to receive(:ssn).and_return(malformed_ssn) }

        it 'logs an error to Sentry' do
          VCR.use_cassette('bgs/vnp_veteran/create') do
            vnp_veteran = BGS::VnpVeteran.new(
              proc_id: '3828241',
              payload: all_flows_payload,
              claim_type: '130DPNEBNADJ',
              icn:,
              common_name:,
              participant_id:,
              ssn: malformed_ssn,
              first_name:,
              middle_name:,
              last_name:
            )
            expect(Rails.logger).to receive(:info).with('Malformed SSN! Reassigning to User#ssn.')
            expect(vnp_veteran).to receive(:log_message_to_sentry).with(
              'SSN is redacted!',
              :error,
              {},
              { team: 'vfs-ebenefits' }
            )
            expect_any_instance_of(BGS::Service).to receive(:create_person).with(vet_person_hash)
            vnp_veteran.create
          end
        end
      end
    end
  end
end
