# frozen_string_literal: true
require 'rails_helper'

require 'saml/settings_service'

require 'sm/client'
require 'support/sm_client_helpers'

RSpec.describe 'API doc validations', type: :request do
  context 'json validation' do
    it 'has valid json' do
      get '/v0/apidocs.json'
      json = response.body
      JSON.parse(json).to_yaml
    end
  end
end

RSpec.describe 'the API documentation', type: :apivore, order: :defined do
  include SM::ClientHelpers
  include AuthenticatedSessionHelper

  subject { Apivore::SwaggerChecker.instance_for('/v0/apidocs.json') }

  let(:rubysaml_settings) { build(:rubysaml_settings) }
  let(:token) { 'lemmein' }
  let(:mhv_user) { build :mhv_user }

  before do
    Session.create(uuid: mhv_user.uuid, token: token)
    User.create(mhv_user)

    allow(SAML::SettingsService).to receive(:saml_settings).and_return(rubysaml_settings)
  end

  context 'has valid paths' do
    let(:auth_options) { { '_headers' => { 'Authorization' => "Token token=#{token}" } } }

    it 'supports new sessions' do
      expect(subject).to validate(:get, '/v0/sessions/new', 200, level: 1)
    end

    it 'supports session deletion' do
      expect(subject).to validate(:delete, '/v0/sessions', 202, auth_options)
      expect(subject).to validate(:delete, '/v0/sessions', 401)
    end

    it 'supports getting an in-progress form' do
      expect(subject).to validate(
        :get,
        '/v0/in_progress_forms/{id}',
        200,
        auth_options.merge('id' => 'healthcare_application')
      )
      expect(subject).to validate(:get, '/v0/in_progress_forms/{id}', 401, 'id' => 'healthcare_application')
    end

    it 'supports updating an in-progress form' do
      expect(subject).to validate(
        :put,
        '/v0/in_progress_forms/{id}',
        200,
        auth_options.merge(
          'id' => 'healthcare_application',
          '_data' => { 'form_data' => { wat: 'foo' } }
        )
      )
      expect(subject).to validate(
        :put,
        '/v0/in_progress_forms/{id}',
        500,
        auth_options.merge('id' => 'healthcare_application')
      )
      expect(subject).to validate(:put, '/v0/in_progress_forms/{id}', 401, 'id' => 'healthcare_application')
    end

    it 'supports adding an education benefits form' do
      expect(subject).to validate(
        :post,
        '/v0/education_benefits_claims/{form_type}',
        200,
        'form_type' => '1990',
        '_data' => {
          'education_benefits_claim' => {
            'form' => build(:education_benefits_claim).form
          }
        }
      )

      expect(subject).to validate(
        :post,
        '/v0/education_benefits_claims/{form_type}',
        422,
        'form_type' => '1990',
        '_data' => {
          'education_benefits_claim' => {
            'form' => {}.to_json
          }
        }
      )
    end

    context 'HCA tests' do
      let(:test_veteran) do
        File.read(
          Rails.root.join('spec', 'fixtures', 'hca', 'veteran.json')
        )
      end

      it 'supports getting the hca health check' do
        VCR.use_cassette('hca/health_check', match_requests_on: [:body]) do
          expect(subject).to validate(
            :get,
            '/v0/health_care_applications/healthcheck',
            200
          )
        end
      end

      it 'supports submitting a health care application', run_at: '2017-01-31' do
        VCR.use_cassette('hca/submit_anon', match_requests_on: [:body]) do
          expect(subject).to validate(
            :post,
            '/v0/health_care_applications',
            200,
            '_data' => {
              'form' => test_veteran
            }
          )
        end

        expect(subject).to validate(
          :post,
          '/v0/health_care_applications',
          422,
          '_data' => {
            'form' => {}.to_json
          }
        )

        allow_any_instance_of(HCA::Service).to receive(:post) do
          raise Common::Client::Errors::HTTPError, 'error message'
        end

        expect(subject).to validate(
          :post,
          '/v0/health_care_applications',
          400,
          '_data' => {
            'form' => test_veteran
          }
        )
      end
    end

    describe 'messaging tests' do
      before(:each) do
        allow(SM::Client).to receive(:new).and_return(authenticated_client)
        use_authenticated_current_user(current_user: mhv_user)
      end

      describe 'triage teams' do
        context 'successful calls' do
          it 'supports getting a list of all prescriptions' do
            VCR.use_cassette('sm_client/triage_teams/gets_a_collection_of_triage_team_recipients') do
              expect(subject).to validate(:get, '/v0/messaging/health/recipients', 200)
            end
          end
        end
      end

      describe 'folders' do
        context 'successful calls' do
          it 'supports getting a list of all folders' do
            VCR.use_cassette('sm_client/folders/gets_a_collection_of_folders') do
              expect(subject).to validate(:get, '/v0/messaging/health/folders', 200)
            end
          end

          it 'supports getting a list of all messages in a folder' do
            VCR.use_cassette('sm_client/folders/nested_resources/gets_a_collection_of_messages') do
              expect(subject).to validate(
                :get,
                '/v0/messaging/health/folders/{folder_id}/messages', 200, 'folder_id' => '0'
              )
            end
          end

          it 'supports getting information about a specific folder' do
            VCR.use_cassette('sm_client/folders/gets_a_single_folder') do
              expect(subject).to validate(:get, '/v0/messaging/health/folders/{id}', 200, 'id' => '0')
            end
          end

          it 'supports creating a new folder' do
            VCR.use_cassette('sm_client/folders/creates_a_folder_and_deletes_a_folder') do
              expect(subject).to validate(:post, '/v0/messaging/health/folders',
                                          201, '_data' => { 'folder' => { 'name' => 'test folder 66745' } })
            end
          end

          it 'supports deleting a folder' do
            VCR.use_cassette('sm_client/folders/creates_a_folder_and_deletes_a_folder') do
              expect(subject).to validate(:delete, '/v0/messaging/health/folders/{id}', 204, 'id' => '674886')
            end
          end
        end
      end

      describe 'messages' do
        context 'successful calls' do
          let(:uploads) do
            [
              Rack::Test::UploadedFile.new('spec/support/fixtures/sm_file1.jpg', 'image/jpg'),
              Rack::Test::UploadedFile.new('spec/support/fixtures/sm_file2.jpg', 'image/jpg'),
              Rack::Test::UploadedFile.new('spec/support/fixtures/sm_file3.jpg', 'image/jpg'),
              Rack::Test::UploadedFile.new('spec/support/fixtures/sm_file4.jpg', 'image/jpg')
            ]
          end

          it 'supports getting a list of all messages in a thread' do
            VCR.use_cassette('sm_client/messages/gets_a_message_thread') do
              expect(subject).to validate(:get, '/v0/messaging/health/messages/{id}/thread', 200, 'id' => '573059')
            end
          end

          it 'supports getting a message' do
            VCR.use_cassette('sm_client/messages/gets_a_message_with_id') do
              expect(subject).to validate(:get, '/v0/messaging/health/messages/{id}', 200, 'id' => '573059')
            end
          end

          it 'supports getting a list of message categories' do
            VCR.use_cassette('sm_client/messages/gets_message_categories') do
              expect(subject).to validate(:get, '/v0/messaging/health/messages/categories', 200)
            end
          end

          it 'supports getting message attachments' do
            VCR.use_cassette('sm_client/messages/nested_resources/gets_a_file_attachment') do
              expect(subject).to validate(:get, '/v0/messaging/health/messages/{message_id}/attachments/{id}',
                                          200, 'message_id' => '629999', 'id' => '629993')
            end
          end

          it 'supports moving a message to another folder' do
            VCR.use_cassette('sm_client/messages/moves_a_message_with_id') do
              expect(subject).to validate(:patch, '/v0/messaging/health/messages/{id}/move',
                                          204, 'id' => '573052', '_query_string' => 'folder_id=0')
            end
          end

          it 'supports creating a message with no attachments' do
            VCR.use_cassette('sm_client/messages/creates/a_new_message_without_attachments') do
              expect(subject).to validate(
                :post, '/v0/messaging/health/messages', 200,
                '_data' => { 'message' => {
                  'subject' => 'CI Run', 'category' => 'OTHER', 'recipient_id' => '613586',
                  'body' => 'Continuous Integration'
                } }
              )
            end
          end

          it 'supports creating a message with attachments' do
            VCR.use_cassette('sm_client/messages/creates/a_new_message_with_4_attachments') do
              expect(subject).to validate(
                :post, '/v0/messaging/health/messages', 200,
                'id' => '674838',
                '_data' => {
                  'message' => {
                    'subject' => 'CI Run', 'category' => 'OTHER', 'recipient_id' => '613586',
                    'body' => 'Continuous Integration'
                  },
                  'uploads' => uploads
                }
              )
            end
          end

          it 'supports replying to a message with no attachments' do
            VCR.use_cassette('sm_client/messages/creates/a_reply_without_attachments') do
              expect(subject).to validate(
                :post, '/v0/messaging/health/messages/{id}/reply', 201,
                'id' => '674838',
                '_data' => { 'message' => {
                  'subject' => 'CI Run', 'category' => 'OTHER', 'recipient_id' => '613586',
                  'body' => 'Continuous Integration'
                } }
              )
            end
          end

          it 'supports replying to a message with attachments' do
            VCR.use_cassette('sm_client/messages/creates/a_reply_with_4_attachments') do
              expect(subject).to validate(
                :post, '/v0/messaging/health/messages/{id}/reply', 201,
                'id' => '674838',
                '_data' => {
                  'message' => {
                    'subject' => 'CI Run', 'category' => 'OTHER', 'recipient_id' => '613586',
                    'body' => 'Continuous Integration'
                  },
                  'uploads' => uploads
                }
              )
            end
          end

          it 'supports deleting a message' do
            VCR.use_cassette('sm_client/messages/deletes_the_message_with_id') do
              expect(subject).to validate(:delete, '/v0/messaging/health/messages/{id}', 204, 'id' => '573052')
            end
          end
        end
      end
    end

    it 'supports getting the user data' do
      expect(subject).to validate(:get, '/v0/user', 200, auth_options)
      expect(subject).to validate(:get, '/v0/user', 401)
    end
  end

  context 'and' do
    it 'tests all documented routes' do
      expect(subject).to validate_all_paths
    end
  end
end
