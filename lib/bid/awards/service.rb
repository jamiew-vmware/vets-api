# frozen_string_literal: true

require_relative 'configuration'
require 'common/client/base'

module BID
  module Awards
    class Service < Common::Client::Base
      include Common::Client::Concerns::Monitoring
      include SentryLogging
      configuration BID::Awards::Configuration
      STATSD_KEY_PREFIX = 'api.bid.awards'

      def get_awards_pension(participant_id:)
        with_monitoring do
          perform(
            :get,
            end_point(participant_id),
            nil,
            request_headers
          )
        end
      end

      private

      def request_headers
        {
          Authorization: "Bearer #{Settings.bid.awards.credentials}"
        }
      end

      def end_point(participant_id)
        "#{Settings.bid.awards.base_url}/api/v1/awards/pension/#{participant_id}"
      end
    end
  end
end
