# frozen_string_literal: true

require_relative 'service'

module BGS
  class StudentSchool
    attr_reader :proc_id, :vnp_participant_id, :icn, :common_name, :dependents_application

    def initialize(proc_id:, vnp_participant_id:, icn:, common_name:, dependents_application:)
      @icn = icn
      @common_name = common_name
      @proc_id = proc_id
      @vnp_participant_id = vnp_participant_id
      @dependents_application = dependents_application
    end

    def create
      child_school = BGSDependents::ChildSchool.new(dependents_application, proc_id, vnp_participant_id)
      child_student = BGSDependents::ChildStudent.new(dependents_application, proc_id, vnp_participant_id)

      bgs_service.create_child_school(child_school_params: child_school.params_for_686c)
      bgs_service.create_child_student(child_student_params: child_student.params_for_686c)
    end

    private

    def bgs_service
      @service ||= BGS::Service.new(icn:, common_name:)
    end
  end
end
