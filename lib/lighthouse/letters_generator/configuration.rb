require 'common/client/configuration/rest'
require 'common/client/middleware/response/raise_error'

module Lighthouse
  module LettersGenerator
    class Configuration < Common::Client::Configuration::REST
      def base_path
        'http://localhost:3000'
      end

      def service_name
        'Lighthouse_LettersGenerator'
      end

      def connection
        @conn ||= Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
          faraday.use      :breakers
          faraday.use      Faraday::Response::RaiseError
  
          faraday.request :multipart
          faraday.request :json
          
          faraday.response :raise_error
          faraday.response :betamocks if mock_enabled?
          faraday.response :json
          faraday.adapter Faraday.default_adapter
        end
      end

      ##
      # @return [Boolean] Should the service use mock data in lower environments.
      #
      def mock_enabled?
        false
      end
    end
  end
end