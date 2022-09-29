# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s
require 'rails_helper'
require_relative '../../../support/swagger_shared_components/v2'

# doc generation for V2 5103 temporarily disabled
describe 'EvidenceWaiver5103', swagger_doc: 'modules/claims_api/app/swagger/claims_api/v2/swagger.json',
                               document: false do
  path '/veterans/{veteranId}/5103' do
    post 'Submit Evidence Waiver 5103' do
      tags '5103 Waiver'
      operationId 'submitEvidenceWaiver5103'
      security [
        { productionOauth: ['claim.write'] },
        { sandboxOauth: ['claim.write'] },
        { bearer_token: [] }
      ]
      consumes 'application/json'
      produces 'application/json'
      description 'Submit Evidence Waiver 5103 for Veteran.'

      let(:Authorization) { 'Bearer token' }
      parameter name: 'veteranId',
                in: :path,
                required: true,
                type: :string,
                description: 'ID of Veteran'

      let(:veteranId) { '1013062086V794840' } # rubocop:disable RSpec/VariableName
      let(:scopes) { %w[claim.write] }
      let(:data) do
        {
        }
      end

      describe 'Getting a successful response' do
        response '200', 'Successful response' do
          schema JSON.parse(File.read(Rails.root.join('spec',
                                                      'support',
                                                      'schemas',
                                                      'claims_api',
                                                      'v2',
                                                      'veterans',
                                                      'submit_waiver_5103.json')))

          before do |example|
            with_okta_user(scopes) do
              submit_request(example.metadata)
            end
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a valid 200 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 401 response' do
        response '401', 'Unauthorized' do
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                                      'default.json')))

          let(:Authorization) { nil }

          before do |example|
            submit_request(example.metadata)
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a 401 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end
    end
  end
end