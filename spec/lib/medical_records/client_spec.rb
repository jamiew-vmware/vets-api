# frozen_string_literal: true

require 'rails_helper'
require 'medical_records/client'

describe MedicalRecords::Client do
  # Fix when authentication is implemented
  before(:all) do
    #   VCR.use_cassette 'mr_client/session', record: :new_episodes do
    #   client =
    @client ||= MedicalRecords::Client.new # (session: { user_id: '10616687' })
    #   client.authenticate
    #   client
    #   end
  end

  let(:client) { @client }

  it 'gets a list of vaccines', :vcr do
    VCR.use_cassette 'mr_client/get_a_list_of_vaccines' do
      vaccine_list = client.list_vaccines(49_006)
      expect(vaccine_list).to be_a(FHIR::Bundle)
    end
  end

  it 'gets a single vaccine', :vcr do
    VCR.use_cassette 'mr_client/get_a_vaccine' do
      vaccine_list = client.get_vaccine(49_432)
      expect(vaccine_list).to be_a(FHIR::Bundle)
    end
  end

  it 'gets a list of radiology reports', :vcr do
    VCR.use_cassette 'mr_client/get_a_list_of_radiology_reports' do
      vaccine_list = client.list_radiology('2934296')
      expect(vaccine_list).to be_a(FHIR::Bundle)
    end
  end

  it 'gets a single document reference', :vcr do
    VCR.use_cassette 'mr_client/get_a_document_reference' do
      document_reference = client.get_document_reference('24cabcdf-dc86-0e48-59d9-3c8000a27726')
      expect(document_reference).to be_a(FHIR::DocumentReference)
    end
  end
end
