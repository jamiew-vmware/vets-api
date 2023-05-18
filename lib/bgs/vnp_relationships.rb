# frozen_string_literal: true

require_relative 'service'

module BGS
  class VnpRelationships
    attr_reader :proc_id, :veteran, :step_children, :dependents, :icn, :common_name

    def initialize(proc_id:, veteran:, step_children:, dependents:, icn:, common_name:) # rubocop:disable Metrics/ParameterLists
      @icn = icn
      @common_name = common_name
      @veteran = veteran
      @proc_id = proc_id
      @step_children = step_children
      @dependents = dependents
    end

    def create_all
      spouse_marriages, vet_dependents = dependents.partition do |dependent|
        dependent[:type] == 'spouse_marriage_history'
      end

      spouse = dependents.find { |dependent| dependent[:type] == 'spouse' }

      send_step_children_relationships if step_children.present?
      send_spouse_marriage_history_relationships(spouse, spouse_marriages)
      send_vet_dependent_relationships(vet_dependents)
    end

    private

    def send_step_children_relationships
      step_children_part, step_children_parents_part = step_children.partition do |dependent|
        dependent[:type] == 'stepchild'
      end

      step_children_part.each do |step_child|
        bgs_service.create_relationship(
          relationship_params: vnp_relationship_params_for_686c(step_child[:guardian_particpant_id], step_child)
        )
      end

      step_children_parents_part.each do |step_child_parent|
        bgs_service.create_relationship(
          relationship_params: vnp_relationship_params_for_686c(veteran[:vnp_participant_id], step_child_parent)
        )
      end
    end

    def send_vet_dependent_relationships(vet_dependents)
      vet_dependents.each do |dependent|
        bgs_service.create_relationship(
          relationship_params: vnp_relationship_params_for_686c(veteran[:vnp_participant_id], dependent)
        )
      end
    end

    def send_spouse_marriage_history_relationships(spouse, spouse_marriages)
      spouse_marriages.each do |dependent|
        bgs_service.create_relationship(
          relationship_params: vnp_relationship_params_for_686c(spouse[:vnp_participant_id], dependent)
        )
      end
    end

    def bgs_service
      BGS::Service.new(icn:, common_name:)
    end

    def format_date(date)
      return nil if date.nil?

      DateTime.parse("#{date} 12:00:00").to_time.iso8601
    end

    def vnp_relationship_params_for_686c(participant_a_id, dependent)
      {
        vnp_proc_id: proc_id,
        vnp_ptcpnt_id_a: participant_a_id,
        vnp_ptcpnt_id_b: dependent[:vnp_participant_id],
        ptcpnt_rlnshp_type_nm: dependent[:participant_relationship_type_name],
        family_rlnshp_type_nm: dependent[:family_relationship_type_name],
        event_dt: format_date(dependent[:event_date]),
        begin_dt: format_date(dependent[:begin_date]),
        end_dt: format_date(dependent[:end_date]),
        marage_cntry_nm: dependent[:marriage_country],
        marage_state_cd: dependent[:marriage_state],
        marage_city_nm: dependent[:marriage_city],
        marage_trmntn_cntry_nm: dependent[:divorce_country],
        marage_trmntn_state_cd: dependent[:divorce_state],
        marage_trmntn_city_nm: dependent[:divorce_city],
        marage_trmntn_type_cd: dependent[:marriage_termination_type_code],
        mthly_support_from_vet_amt: dependent[:living_expenses_paid_amount],
        child_prevly_married_ind: dependent[:child_prevly_married_ind],
        dep_has_income_ind: dependent[:dep_has_income_ind]
      }
    end
  end
end
