# frozen_string_literal: true

require 'disability_compensation/providers/intent_to_file/intent_to_file_provider'
require 'disability_compensation/responses/intent_to_files_response'
require 'lighthouse/benefits_claims/service'

class LighthouseIntentToFileProvider
  include IntentToFileProvider

  def initialize(current_user)
    icn = current_user.icn
    ssn = current_user.ssn
    @service = BenefitsClaims::Service.new(icn, ssn)
  end

  def get_intent_to_file(type, lighthouse_client_id, lighthouse_rsa_key_path)
    data = @service.get_intent_to_file(type, lighthouse_client_id, lighthouse_rsa_key_path)['data']
    transform(data)
  end

  # TODO: return 401 response if something is missing?
  def create_intent_to_file(type, lighthouse_client_id, lighthouse_rsa_key_path)
    data = @service.create_intent_to_file(type, lighthouse_client_id, lighthouse_rsa_key_path)['data']
    transform(data)
  end

  private

  def transform(data)
    DisabilityCompensation::ApiProvider::IntentToFilesResponse.new(
      intent_to_file: [
        DisabilityCompensation::ApiProvider::IntentToFile.new(
          id: data['id'],
          creation_date: data['attributes']['creationDate'],
          expiration_date: data['attributes']['expirationDate'],
          source: '',
          participant_id: 0,
          status: data['attributes']['status'],
          type: data['attributes']['type']
        )
      ]
    )
  end
end
