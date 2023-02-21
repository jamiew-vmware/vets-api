# frozen_string_literal: true

require 'common/file_helpers'
require 'common/virus_scan'

module UploaderVirusScan
  extend ActiveSupport::Concern

  class VirusFoundError < StandardError
  end

  included do
    before(:store, :validate_virus_free)
  end

  def validate_virus_free(file)
    return unless Rails.env.production?

    temp_file_path = Common::FileHelpers.generate_temp_file(file.read)
    client, result = Common::VirusScan.scan(temp_file_path)
    File.delete(temp_file_path)

    # Common::VirusScan result will return true or false
    unless client.safe?(temp_file_patch)
      file.delete
      raise VirusFoundError, (result.virus_name || "")
    end
  end
end
