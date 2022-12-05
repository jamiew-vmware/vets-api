# frozen_string_literal: true

module AppealsApi
  module ReportRecipientsReader
    def self.fetch_recipients(recipient_file_name)
      env = Settings.vsp_environment
      hash = YAML.load_file(recipient_file_name)
      env_hash = hash[env.to_s].nil? ? [] : hash[env.to_s]
      env_hash + hash['common']
    end
  end
end
