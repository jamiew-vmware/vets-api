# frozen_string_literal: true

require 'clamav/commands/patch_scan_command'
require 'clamav/patch_client'

module Common
  module VirusScan
    module_function

    def scan(file_path)
      # `clamd` runs within service group, needs group read
      File.chmod(0o640, file_path)

      client = ClamAV::PatchClient.new
      result = client.execute(ClamAV::Commands::PatchScanCommand.new(file_path))

      virus_name = result.first.virus_name || "" #returns an array, but we will only ever send 1 file

      return client.safe?(file_path), virus_name
    end
  end
end
