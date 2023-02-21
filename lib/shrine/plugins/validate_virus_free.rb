# frozen_string_literal: true

require 'common/virus_scan'
require 'ddtrace'

class Shrine
  module Plugins
    module ValidateVirusFree
      module AttacherMethods
        def validate_virus_free(message: nil)
          Datadog::Tracing.trace('Scan Upload for Viruses') do
            temp_file_path = Common::FileHelpers.generate_temp_file(get.download)
            result = Common::VirusScan.scan(temp_file_path)
            result || add_error_msg(message)
          end
        end

        private

        def add_error_msg(message)
          if Rails.env.development? && message.match(/nodename nor servname provided/)
            Shrine.logger.error('VIRUS SCANNING IS OFF. PLEASE START CLAMD')
            true
          else
            errors << (message || 'virus or malware detected')
            false
          end
        end
      end
    end

    register_plugin(:validate_virus_free, ValidateVirusFree)
  end
end
