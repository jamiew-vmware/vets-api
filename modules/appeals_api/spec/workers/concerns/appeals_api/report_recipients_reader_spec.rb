# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::ReportRecipientsReader do
  describe 'load_recipients' do
    it 'loads no users when file is missing' do
      allow(YAML).to receive(:load_file).and_raise('file does not exist')
      File.stub(:exist?).and_return(false)
      with_settings(Settings, vsp_environment: 'production') do
        expect(subject.load_recipients(:error_report_daily)).to be_empty
      end
    end

    it 'loads no users when file is empty' do
      allow(YAML).to receive(:load_file).and_return(nil)
      with_settings(Settings, vsp_environment: 'production') do
        expect(subject.load_recipients(:error_report_daily)).to be_empty
      end
    end

    it 'loads no users when file has keys but no values' do
      allow(YAML).to receive(:load_file).and_return({ 'common' => nil, 'production' => nil })
      with_settings(Settings, vsp_environment: 'production') do
        expect(subject.load_recipients(:error_report_daily)).to be_empty
      end
    end

    it 'loads prod users and common users' do
      allow(YAML).to receive(:load_file).and_return({ 'common' => %w[cu1 cu2], 'production' => %w[p1 p2] })
      with_settings(Settings, vsp_environment: 'production') do
        expect(subject.load_recipients(:error_report_daily)).to match_array(%w[cu1 cu2 p1 p2])
      end
    end

    it 'loads common users' do
      allow(YAML).to receive(:load_file).and_return({ 'common' => %w[cu1 cu2], 'production' => [] })
      with_settings(Settings, vsp_environment: 'production') do
        expect(subject.load_recipients(:error_report_daily)).to match_array(%w[cu1 cu2])
      end
    end
  end
end
