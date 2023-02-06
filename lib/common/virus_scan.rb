# frozen_string_literal: true

module Common
  module VirusScan
    module_function

    def scan(file_path)
      # `clamd` runs within service group, needs group read
      File.chmod(0o640, file_path)

      # NOTE: If using custom_args, no other arguments can be passed to
      # ClamScan::Client.scan. All other arguments will be ignored
      # args = ['-c', Rails.root.join('config', 'clamd.conf').to_s, file_path]
      # ClamScan::Client.scan(custom_args: args)

      clamav = TCPSocket.open('127.0.0.1', 3310)
      stripped_filename = file_path.gsub(%r{^tmp/}, '')
      request = "SCAN /vets-api/#{stripped_filename}" # call the shared volume on clamav container
      clamav.puts(request)
      return clamav.gets
      clamav.close
    end
  end
end
