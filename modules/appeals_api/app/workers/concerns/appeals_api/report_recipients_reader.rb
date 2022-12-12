# frozen_string_literal: true

module AppealsApi
  module ReportRecipientsReader
    def self.load_recipients(recipient_file_name)
      env = Settings.vsp_environment
      recipient_file_path = AppealsApi::Engine.root.join('config', 'mailinglists', "#{recipient_file_name}.yml")
      hash = File.exist?(recipient_file_path) ? (YAML.load_file(recipient_file_path) || {}) : {}
      env_hash = hash.fetch(env.to_s, []) || []
      env_hash + (hash['common'] || [])
    end
  end
end
