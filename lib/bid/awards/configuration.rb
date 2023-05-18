# frozen_string_literal: true

module BID
  module Awards
    class Configuration < Common::Client::Configuration::REST
      def connection
        @conn ||= Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
          faraday.use :breakers
          faraday.use Faraday::Response::RaiseError
          faraday.response :betamocks if mock_enabled?
          faraday.response :snakecase, symbolize: false
          faraday.response :json, content_type: /\bjson/
          faraday.adapter Faraday.default_adapter
        end
      end

      def base_path
        "#{Settings.bid.awards.base_url}/api/v1/awards/"
      end

      def service_name
        'BID/Awards'
      end

      def mock_enabled?
        Settings.bid.awards.mock || false
      end
    end
  end
end
