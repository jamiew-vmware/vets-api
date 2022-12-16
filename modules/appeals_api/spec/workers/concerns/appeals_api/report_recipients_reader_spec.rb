# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::ReportRecipientsReader do
  let(:test_class) { Class.new { include AppealsApi::ReportRecipientsReader } }
  let(:report) { test_class.new }

  describe 'load_recipients' do
    let(:expected_file_path) { AppealsApi::Engine.root.join('config', 'mailinglists', 'error_report_daily.yml').to_s }
    let(:messager_instance) { instance_double('AppealsApi::Slack::Messager') }

    it 'loads no users when file is missing' do
      expected_notify = { warning: ':warning:  recipients file does not exist',
                          recipient_file: expected_file_path }
      allow(AppealsApi::Slack::Messager).to receive(:new).with(expected_notify).and_return(messager_instance)
      expect(messager_instance).to receive(:notify!)
      expect(File).to receive(:exist?).and_return(false)
      with_settings(Settings, vsp_environment: 'production') do
        expect(report.load_recipients(:error_report_daily)).to be_empty
      end
    end

    it 'loads no users when file is empty(no keys)' do
      expected_notify = { warning: ':warning:  report has no configured recipients',
                          recipient_file: expected_file_path }
      allow(AppealsApi::Slack::Messager).to receive(:new).with(expected_notify).and_return(messager_instance)
      expect(messager_instance).to receive(:notify!)
      allow(YAML).to receive(:load_file).and_return(nil)
      with_settings(Settings, vsp_environment: 'production') do
        expect(report.load_recipients(:error_report_daily)).to be_empty
      end
    end

    it 'loads no users when file has keys but no values' do
      expected_notify = { warning: ':warning:  report has no configured recipients',
                          recipient_file: expected_file_path }
      allow(AppealsApi::Slack::Messager).to receive(:new).with(expected_notify).and_return(messager_instance)
      expect(messager_instance).to receive(:notify!)
      allow(YAML).to receive(:load_file).and_return({ 'common' => nil, 'production' => nil })
      with_settings(Settings, vsp_environment: 'production') do
        expect(report.load_recipients(:error_report_daily)).to be_empty
      end
    end

    it 'loads prod users and common users' do
      allow(YAML).to receive(:load_file).and_return({ 'common' => %w[cu1 cu2], 'production' => %w[p1 p2] })
      with_settings(Settings, vsp_environment: 'production') do
        expect(report.load_recipients(:error_report_daily)).to match_array(%w[cu1 cu2 p1 p2])
      end
    end

    it 'loads common users' do
      allow(YAML).to receive(:load_file).and_return({ 'common' => %w[cu1 cu2], 'production' => [] })
      with_settings(Settings, vsp_environment: 'production') do
        expect(report.load_recipients(:error_report_daily)).to match_array(%w[cu1 cu2])
      end
    end
  end
end
