require 'common/client/configuration/rest'
require 'common/client/middleware/response/raise_error'

module Lighthouse
  module LettersGenerator
    class Configuration < Common::Client::Configuration::REST

      def base_path
        ''
      end

      def service_name
        'Lighthouse_LettersGenerator'
      end

      def connection
        # Connection.new()
      end
    end

    # class Connection
    #   def builder
    #     Builder.new()
    #   end

    #   def get(path, icn)
    #     {}
    #   end

    #   def send(method, path, params)
    #     Response.new()
    #   end
    # end

    # class Builder
    #   def handlers
    #     []
    #   end
    # end

    # class Response
    #   def env
    #   end
    # end
  end
end