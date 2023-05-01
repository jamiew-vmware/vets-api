# frozen_string_literal: true

module ClaimsApi
  class ClaimsUser
    def initialize(id)
      @uuid = id
      @identifier = UserIdentifier.new(id)
    end

    def set_icn(icn)
      @identifier.set_icn(icn)
    end

    def icn
      @identifier.icn
    end

    def loa
      @identifier.loa
    end

    attr_reader :uuid, :first_name, :last_name

    def authn_context
      'authn'
    end

    def mhv_icn
      @identifier.icn
    end

    def first_name_last_name(first_name, last_name)
      @first_name = first_name
      @last_name = last_name
      @identifier.first_name_last_name(first_name, last_name)
    end
  end
end
