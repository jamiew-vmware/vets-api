# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'letters', type: :request do
  include JsonSchemaMatchers

  let(:rsa_key) { OpenSSL::PKey::RSA.generate(2048) }
  let(:letters_body) do
    {
      'data' => {
        'id' => '3097e489-ad75-5746-ab1a-e0aabc1b426a',
        'type' => 'letters',
        'attributes' => {
          'letters' =>
            [
              {
                'name' => 'Commissary Letter',
                'letterType' => 'commissary'
              },
              {
                'name' => 'Proof of Service Letter',
                'letterType' => 'proof_of_service'
              },
              {
                'name' => 'Proof of Creditable Prescription Drug Coverage Letter',
                'letterType' => 'medicare_partd'
              },
              {
                'name' => 'Proof of Minimum Essential Coverage Letter',
                'letterType' => 'minimum_essential_coverage'
              },
              {
                'name' => 'Service Verification Letter',
                'letterType' => 'service_verification'
              },
              {
                'name' => 'Civil Service Preference Letter',
                'letterType' => 'civil_service'
              },
              {
                'name' => 'Benefit Summary and Service Verification Letter',
                'letterType' => 'benefit_summary'
              },
              {
                'name' => 'Benefit Verification Letter',
                'letterType' => 'benefit_verification'
              }
            ]
        }
      }
    }
  end

  before do
    allow(File).to receive(:read).and_return(rsa_key.to_s)
    allow(File).to receive(:read).and_call_original
    allow_any_instance_of(IAMUser).to receive(:icn).and_return('24811694708759028')
    iam_sign_in(build(:iam_user))
    Flipper.enable(:mobile_lighthouse_letters)
  end

  before(:all) do
    @original_cassette_dir = VCR.configure(&:cassette_library_dir)
    VCR.configure { |c| c.cassette_library_dir = 'modules/mobile/spec/support/vcr_cassettes' }
  end

  after(:all) { VCR.configure { |c| c.cassette_library_dir = @original_cassette_dir } }

  describe 'GET /mobile/v0/letters' do
    context 'with a valid lighthouse response' do
      it 'matches the letters schema' do
        VCR.use_cassette('lighthouse_letters/letters_200', match_requests_on: %i[method uri]) do
          get '/mobile/v0/letters', headers: iam_headers
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to eq(letters_body)
          expect(response.body).to match_json_schema('letters')
        end
      end
    end
  end

  describe 'error handling' do
    context 'with a letter generator service error' do
      it 'returns a not found response' do
        VCR.use_cassette('evss/letters/letters_letter_generator_service_error') do
          get '/mobile/v0/letters', headers: iam_headers
          expect(response).to have_http_status(:service_unavailable)
          expect(response.body).to match_json_schema('evss_errors')
        end
      end
    end

    context 'with one or more letter destination errors' do
      it 'returns a not found response' do
        VCR.use_cassette('evss/letters/letters_letter_destination_error') do
          get '/mobile/v0/letters', headers: iam_headers
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.body).to match_json_schema('evss_errors')
        end
      end
    end

    context 'with an invalid address error' do
      context 'when the user has not been logged' do
        it 'logs the user edipi' do
          VCR.use_cassette('evss/letters/letters_invalid_address') do
            expect { get '/mobile/v0/letters', headers: iam_headers }.to change(InvalidLetterAddressEdipi, :count).by(1)
            expect(response).to have_http_status(:unprocessable_entity)
          end
        end
      end

      context 'when log record insertion fails' do
        it 'stills return unprocessable_entity' do
          VCR.use_cassette('evss/letters/letters_invalid_address') do
            allow(InvalidLetterAddressEdipi).to receive(:find_or_create_by).and_raise(ActiveRecord::ActiveRecordError)
            expect { get '/mobile/v0/letters', headers: iam_headers }.to change(InvalidLetterAddressEdipi, :count).by(0)
            expect(response).to have_http_status(:unprocessable_entity)
          end
        end
      end
    end

    context 'with a not eligible error' do
      it 'returns a not found response' do
        VCR.use_cassette('evss/letters/letters_not_eligible_error') do
          get '/mobile/v0/letters', headers: iam_headers
          expect(response).to have_http_status(:bad_gateway)
          expect(response.body).to match_json_schema('evss_errors')
          expect(JSON.parse(response.body)).to have_deep_attributes(
            'errors' => [
              {
                'title' => 'Proxy error',
                'detail' => 'Upstream server returned not eligible response',
                'code' => '111',
                'source' => 'EVSS::Letters::Service',
                'status' => '502',
                'meta' => {
                  'messages' => [
                    {
                      'key' => 'lettergenerator.notEligible',
                      'severity' => 'FATAL',
                      'text' => 'Veteran is not eligible to receive the letter'
                    }
                  ]
                }
              }
            ]
          )
        end
      end
    end

    context 'with can not determine eligibility error' do
      it 'returns a not found response' do
        VCR.use_cassette('evss/letters/letters_determine_eligibility_error') do
          get '/mobile/v0/letters', headers: iam_headers
          expect(response).to have_http_status(:bad_gateway)
          expect(response.body).to match_json_schema('evss_errors')
          expect(JSON.parse(response.body)).to have_deep_attributes(
            'errors' => [
              {
                'title' => 'Proxy error',
                'detail' => 'Can not determine eligibility for potential letters due to upstream server error',
                'code' => '110',
                'source' => 'EVSS::Letters::Service',
                'status' => '502',
                'meta' => {
                  'messages' => [
                    {
                      'key' => 'letterGeneration.letterEligibilityError',
                      'severity' => 'FATAL',
                      'text' => 'Unable to determine eligibility on potential letters'
                    }
                  ]
                }
              }
            ]
          )
        end
      end
    end
  end
end
