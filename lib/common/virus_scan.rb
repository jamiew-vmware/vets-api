# frozen_string_literal: true

module Common
  module VirusScan
    module_function

    def scan(file_path)
      File.chmod(0o640, file_path)
      clamav = TCPSocket.open('127.0.0.1', 3310)
      stripped_filename = file_path.gsub(%r{^tmp/}, '')
      request = "SCAN /vets-api/#{stripped_filename}" # call the shared volume on clamav container
      clamav.puts(request)
      return clamav.gets
      clamav.close
    end

    def safe?
      #Todo
    end
  end
end
