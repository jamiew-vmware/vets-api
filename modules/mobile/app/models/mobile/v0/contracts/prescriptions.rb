# frozen_string_literal: true

module Mobile
  module V0
    module Contracts
      class Prescriptions < PaginationBase
        params do
          optional(:sort).maybe(:string, :filled?)
        end
      end
    end
  end
end
