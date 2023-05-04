# frozen_string_literal: true

require 'disability_compensation/providers/intent_to_file/intent_to_file_provider'
require 'lighthouse/benefits_claims/service'

class LighthouseIntentToFileProvider
include IntentToFileProvider

  def initialize(current_user)
    icn = current_user.icn
    @service = BenefitsClaims::Service.new(icn)
  end

  def get_intent_to_file(type, lighthouse_client_id, lighthouse_rsa_key_path)
    data = @service.get_intent_to_file(type, lighthouse_client_id, lighthouse_rsa_key_path)['data']
    # return 404 response if something is missing?
    # hold for error handling utility
    transform(data)
  end
  
  def create_intent_to_file(type)
    # Will implement in 57064
    # data = @service.get_intent_to_file(type)['data']
    # return 401 response if something is missing?
    # transform(data)
  end

  private

  def transform(data)
    DisabilityCompensation::ApiProvider::IntentToFilesResponse.new(
      intent_to_file: [
        DisabilityCompensation::ApiProvider::IntentToFile.new(
          id: data['id'],
          creation_date: data['creationDate'],
          expiration_date: data['expirationDate'],
          source: nil,
          participant_id: nil,
          status: data['status'],
          type: data['type']
        )
      ]
    ) 
  end
end
  