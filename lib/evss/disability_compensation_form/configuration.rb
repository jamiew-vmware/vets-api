# frozen_string_literal: true

require 'evss/configuration'

module EVSS
  module DisabilityCompensationForm
    # Configuration for the 526 form, used by the {EVSS::DisabilityCompensationForm::Service} to
    # set the base path, a default timeout, and a service name for breakers and metrics
    #
    class Configuration < EVSS::Configuration
      self.read_timeout = Settings.evss.disability_compensation_form.timeout || 55

      # @return [String] The base path for the EVSS 526 endpoints
      #
      def base_path
        if Flipper.enabled? :form526_dvp
          dvp_base_path()
        else
          "#{Settings.evss.url}/#{Settings.evss.alternate_service_name}/rest/form526/v2"
        end
      end

      # @return [String] The base path for the EVSS Form 526 endpoints in DVP
      #
      def dvp_base_path
        dvp_env = Settings.evss.dvp.current_env
        "#{Settings.evss.dvp[dvp_env].url}/#{Settings.evss.dvp[dvp_env].service_name}/rest/form526/v2"
      end

      # @return [String] The name of the service, used by breakers to set a metric name for the service
      #
      def service_name
        'EVSS/DisabilityCompensationForm'
      end

      # @return [Boolean] Whether or not Betamocks mock data is enabled
      #
      def mock_enabled?
        Settings.evss.mock_disabilities_form || false
      end
    end
  end
end
