# frozen_string_literal: true

require 'common/virus_scan'

module UploaderHelpers
  extend ActiveSupport::Concern

  module ClassMethods
    def stub_virus_scan
      before do
        allow(Common::VirusScan).to receive(:scan).and_return(OpenStruct.new(true))
      end
    end
  end
end
