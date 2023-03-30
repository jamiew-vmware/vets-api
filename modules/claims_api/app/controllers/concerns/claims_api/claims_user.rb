module ClaimsApi
  class ClaimsUser
    def initialize(id)
      @id = id
      @uuid = id
      @loa = {:current => 3, :highest => 3}
      @identifier = UserIdentifier.new(id)
    end

    def set_icn(icn)
      @icn = icn
      @identifier.set_icn(icn)
    end

    attr_reader :icn
    attr_reader :uuid

    def first_name_last_name(first_name, last_name)
      @first_name = first_name
      @last_name = last_name
      @identifier.first_name_last_name(first_name, last_name)
    end

    attr_reader :first_name

    attr_reader :last_name
  end
end