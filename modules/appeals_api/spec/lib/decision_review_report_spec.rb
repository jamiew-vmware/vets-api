# frozen_string_literal: true

require 'rails_helper'
require 'appeals_api/decision_review_report'

describe AppealsApi::DecisionReviewReport do
  # rubocop:disable Layout/FirstHashElementIndentation
  shared_examples 'stuck appeals' do |opts|
    it 'retrieves records stuck in incomplete statuses' do
      stuck_appeal_no_updates = nil
      stuck_appeal_with_updates = nil
      unstuck_appeal = nil

      Timecop.freeze 1.year.ago do
        stuck_appeal_no_updates = create(opts[:record_type])
        stuck_appeal_with_updates = create(opts[:record_type])
        unstuck_appeal = create(opts[:record_type])
      end
      unstuck_appeal.update! status: :complete, updated_at: 3.months.ago
      stuck_appeal_with_updates.update! status: :submitting, updated_at: 3.months.ago

      result = subject.send(opts[:method]).pluck(:id)

      expect(result).not_to include unstuck_appeal.id
      expect(result).to include stuck_appeal_no_updates.id
      expect(result).to include stuck_appeal_with_updates.id
    end
  end

  it 'can correctly calculate hlrs' do
    create :higher_level_review, status: 'processing'
    create :higher_level_review, status: 'processing'
    create :higher_level_review, status: 'processing'

    create :higher_level_review, created_at: 1.week.ago, status: 'success'
    create :higher_level_review_v2, status: 'success'
    create :higher_level_review_v2, status: 'complete'

    create :higher_level_review, :status_error

    subject = described_class.new(from: 5.days.ago, to: Time.now.utc)

    expect(subject.hlr_by_status_and_count).to eq({
      'complete' => 1,
      'error' => 1,
      'expired' => 0,
      'pending' => 0,
      'processing' => 3,
      'received' => 0,
      'submitted' => 0,
      'submitting' => 0,
      'success' => 1,
      'uploaded' => 0
    })
  end

  describe '#faulty_hlr' do
    let(:old_error) { create(:higher_level_review, :status_error, created_at: 1.year.ago) }
    let(:recent_error) { create(:higher_level_review, :status_error, created_at: 1.day.ago) }

    it 'will retrieve recent errored records if dates are provided' do
      subject = described_class.new(from: 5.days.ago, to: Time.now.utc)

      expect(subject.faulty_hlr).to eq([recent_error])
    end

    it 'will retrieve all errored records if no dates are provided' do
      subject = described_class.new(from: nil, to: nil)

      expect(subject.faulty_hlr).to eq([recent_error, old_error])
    end
  end

  describe '#stuck_hlr' do
    it 'ignores HLRv1 records' do
      stuck_appeal_no_updates = nil
      stuck_appeal_with_updates = nil
      unstuck_appeal = nil

      Timecop.freeze(1.year.ago) do
        stuck_appeal_no_updates = create(:higher_level_review)
        stuck_appeal_with_updates = create(:higher_level_review)
        unstuck_appeal = create(:higher_level_review)
      end

      unstuck_appeal.update! status: :complete, updated_at: 3.months.ago
      stuck_appeal_with_updates.update! status: :submitting, updated_at: 3.months.ago

      result = subject.stuck_hlr.pluck(:id)

      expect(result).not_to include unstuck_appeal.id
      expect(result).not_to include stuck_appeal_no_updates.id
      expect(result).not_to include stuck_appeal_with_updates.id
    end

    it_behaves_like 'stuck appeals', record_type: :higher_level_review_v2, method: :stuck_hlr
  end

  describe '#total_hlr_successes' do
    it 'shows correct count of all successful HLRs regardless of timeframe' do
      create_list :higher_level_review, 1, created_at: 3.weeks.ago # Ignored
      create_list :higher_level_review, 2, status: 'success', created_at: 3.weeks.ago # Added to total
      create_list :higher_level_review_v2, 4, status: 'success', created_at: 4.weeks.ago # Ignored
      create_list :higher_level_review_v2, 8, status: 'complete', created_at: 4.weeks.ago # Added to total
      expect(subject.total_hlr_successes).to eq 10
    end
  end

  it 'can correctly calculate nods' do
    create :notice_of_disagreement, created_at: 1.week.ago, status: 'success'
    create :notice_of_disagreement, status: 'success'
    create :notice_of_disagreement, status: 'complete'

    create :notice_of_disagreement, :status_error

    subject = described_class.new(from: 5.days.ago, to: Time.now.utc)

    expect(subject.nod_by_status_and_count).to eq({
      'complete' => 1,
      'error' => 1,
      'pending' => 0,
      'processing' => 0,
      'submitted' => 0,
      'submitting' => 0,
      'success' => 1
    })
  end

  describe '#faulty_nod' do
    let(:old_error) { create(:notice_of_disagreement, :status_error, created_at: 1.year.ago) }
    let(:recent_error) { create(:notice_of_disagreement, :status_error, created_at: 1.day.ago) }

    it 'will retrieve recent errored records if dates are provided' do
      subject = described_class.new(from: 5.days.ago, to: Time.now.utc)

      expect(subject.faulty_nod).to eq([recent_error])
    end

    it 'will retrieve all errored records if no dates are provided' do
      subject = described_class.new(from: nil, to: nil)

      expect(subject.faulty_nod).to eq([recent_error, old_error])
    end
  end

  describe '#stuck_nod' do
    it_behaves_like 'stuck appeals', record_type: :notice_of_disagreement, method: :stuck_nod
  end

  describe '#total_nod_successes' do
    it 'shows correct count of all successful NODs regardless of timeframe' do
      create_list :notice_of_disagreement, 5, created_at: 3.weeks.ago
      create_list :notice_of_disagreement, 5, status: 'success', created_at: 3.weeks.ago
      expect(subject.total_nod_successes).to eq 5
    end
  end

  it 'can correctly calculate SCs' do
    create :supplemental_claim, :status_success, created_at: 1.week.ago
    create :supplemental_claim, :status_success
    create :supplemental_claim, :status_success

    create :supplemental_claim, :status_error

    subject = described_class.new(from: 5.days.ago, to: Time.now.utc)

    expect(subject.sc_by_status_and_count).to match_array({
      'complete' => 0,
      'error' => 1,
      'pending' => 0,
      'processing' => 0,
      'submitted' => 0,
      'submitting' => 0,
      'success' => 2
    })
  end

  describe '#faulty_sc' do
    let(:old_error) { create(:supplemental_claim, :status_error, created_at: 1.year.ago) }
    let(:recent_error) { create(:supplemental_claim, :status_error, created_at: 1.day.ago) }

    it 'will retrieve recent errored records if dates are provided' do
      subject = described_class.new(from: 5.days.ago, to: Time.now.utc)

      expect(subject.faulty_sc).to eq([recent_error])
    end

    it 'will retrieve all errored records if no dates are provided' do
      subject = described_class.new(from: nil, to: nil)

      expect(subject.faulty_sc).to eq([recent_error, old_error])
    end
  end

  describe '#stuck_sc' do
    it_behaves_like 'stuck appeals', record_type: :supplemental_claim, method: :stuck_sc
  end

  describe '#total_sc_successes' do
    it 'shows correct count of all successful SCs regardless of timeframe' do
      create_list :supplemental_claim, 5, created_at: 3.weeks.ago
      create_list :supplemental_claim, 5, :status_success, created_at: 3.weeks.ago
      expect(subject.total_sc_successes).to eq 5
    end
  end

  describe 'evidence submissions' do
    describe 'nod' do
      let!(:evidence_submission_1) { create(:evidence_submission) }
      let!(:evidence_submission_2) { create(:evidence_submission, created_at: 1.week.ago) }

      describe '#evidence_submission_by_status_and_count' do
        it 'will retrieve recent errored records if dates are provided' do
          subject = described_class.new(from: 5.days.ago, to: Time.now.utc)

          expect(subject.evidence_submission_by_status_and_count).to eq({
            'error' => 0,
            'expired' => 0,
            'pending' => 1,
            'processing' => 0,
            'received' => 0,
            'success' => 0,
            'uploaded' => 0,
            'vbms' => 0
          })
        end

        it 'will retrieve all errored records if no dates are provided' do
          subject = described_class.new(from: nil, to: nil)

          expect(subject.evidence_submission_by_status_and_count).to eq({
            'error' => 0,
            'expired' => 0,
            'pending' => 2,
            'processing' => 0,
            'received' => 0,
            'success' => 0,
            'uploaded' => 0,
            'vbms' => 0
          })
        end
      end

      describe '#faulty_evidence_submission' do
        let!(:recent_error) { create(:evidence_submission, :status_error, created_at: 1.day.ago) }
        let!(:old_error) { create(:evidence_submission, :status_error, created_at: 1.year.ago) }

        it 'will retrieve recent errored records if dates are provided' do
          subject = described_class.new(from: 5.days.ago, to: Time.now.utc)
          expect(subject.faulty_evidence_submission).to eq([recent_error])
        end

        it 'will retrieve all errored records if no dates are provided' do
          subject = described_class.new(from: nil, to: nil)

          expect(subject.faulty_evidence_submission).to eq([recent_error, old_error])
        end
      end
    end

    describe 'sc' do
      describe '#evidence_submission_by_status_and_count' do
        it 'will retrieve recent errored records if dates are provided' do
          create(:sc_evidence_submission)
          create(:sc_evidence_submission, created_at: 1.week.ago)
          create(:evidence_submission)

          subject = described_class.new(from: 5.days.ago, to: Time.now.utc)

          expect(subject.sc_evidence_submission_by_status_and_count).to eq({
            'error' => 0,
            'expired' => 0,
            'pending' => 1,
            'processing' => 0,
            'received' => 0,
            'success' => 0,
            'uploaded' => 0,
            'vbms' => 0
          })
        end

        it 'will retrieve all errored records if no dates are provided' do
          create(:sc_evidence_submission)
          create(:sc_evidence_submission, created_at: 1.week.ago)
          create(:evidence_submission)

          subject = described_class.new(from: nil, to: nil)

          expect(subject.sc_evidence_submission_by_status_and_count).to eq({
            'error' => 0,
            'expired' => 0,
            'pending' => 2,
            'processing' => 0,
            'received' => 0,
            'success' => 0,
            'uploaded' => 0,
            'vbms' => 0
          })
        end
      end

      describe '#faulty_evidence_submission' do
        let!(:recent_evidence_submission_error) { create(:evidence_submission, :status_error, created_at: 1.day.ago) }
        let!(:recent_error) { create(:sc_evidence_submission, :status_error, created_at: 1.day.ago) }
        let!(:old_error) { create(:sc_evidence_submission, :status_error, created_at: 1.year.ago) }

        it 'will retrieve recent errored records if dates are provided' do
          subject = described_class.new(from: 5.days.ago, to: Time.now.utc)

          expect(subject.sc_faulty_evidence_submission).to eq([recent_error])
        end

        it 'will retrieve all errored records if no dates are provided' do
          subject = described_class.new(from: nil, to: nil)

          expect(subject.sc_faulty_evidence_submission).to eq([recent_error, old_error])
        end
      end
    end
  end
  # rubocop:enable Layout/FirstHashElementIndentation

  describe '#no_faulty_records?' do
    it 'returns false if there are records with a faulty status' do
      create :notice_of_disagreement, :status_error

      expect(described_class.new.no_faulty_records?).to eq(false)
    end

    it 'returns true if there are no records with a faulty status' do
      expect(described_class.new.no_faulty_records?).to eq(true)
    end
  end
end
