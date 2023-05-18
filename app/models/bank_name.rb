# frozen_string_literal: true

require 'common/models/concerns/cache_aside'

class BankName < Common::RedisStore
  redis_store REDIS_CONFIG[:bank_name][:namespace]
  redis_ttl REDIS_CONFIG[:bank_name][:each_ttl]
  redis_key :routing_number

  attribute :bank_name, String
  attribute :routing_number, String

  validates(:routing_number, :bank_name, presence: true)
end
