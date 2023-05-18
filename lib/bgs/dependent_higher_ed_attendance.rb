# frozen_string_literal: true

require_relative 'service'

module BGS
  class DependentHigherEdAttendance
    attr_reader :proc_id, :dependents_application, :icn, :ssn, :common_name

    def initialize(proc_id:, dependents_application:, icn:, ssn:, common_name:)
      @proc_id = proc_id
      @dependents_application = dependents_application
      @icn = icn
      @ssn = ssn
      @common_name = common_name
    end

    def create
      adult_attending_school = BGSDependents::AdultChildAttendingSchool.new(dependents_application)
      formatted_info = adult_attending_school.format_info
      participant = bgs_service.create_participant(proc_id:, ssn:)

      bgs_service.create_person(person_params: person_params(adult_attending_school, participant, formatted_info))
      send_address(adult_attending_school, participant, adult_attending_school.address)

      adult_attending_school.serialize_dependent_result(
        participant,
        'Child',
        'Biological',
        {
          type: '674',
          dep_has_income_ind: formatted_info['dependent_income']
        }
      )
    end

    def person_params(calling_object, participant, dependent_info)
      calling_object.create_person_params(proc_id, participant[:vnp_ptcpnt_id], dependent_info)
    end

    def send_address(calling_object, participant, address_info)
      address = calling_object.generate_address(address_info)
      address_params = calling_object.create_address_params(proc_id, participant[:vnp_ptcpnt_id], address)

      bgs_service.create_address(address_params:)
    end

    def bgs_service
      @bgs_service ||= BGS::Service.new(icn:, common_name:)
    end
  end
end
