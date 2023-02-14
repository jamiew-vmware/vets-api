# frozen_string_literal: true

require 'rails_helper'

shared_examples 'notice of disagreements v2 and v3 structure examples' do
  let(:notice_of_disagreement) { create(:extra_notice_of_disagreement_v2) }

  describe '#form_fill' do
    it 'returns a Hash' do
      result = described_class.new(notice_of_disagreement).form_fill

      expect(result.class).to eq(Hash)
    end
  end

  describe '#insert_overlaid_pages' do
    it 'returns a temporary overlaid pdf path' do
      form_fill_path = Prawn::Document.new.render_file("/tmp/#{notice_of_disagreement.id}.pdf")
      result = described_class.new(notice_of_disagreement).insert_overlaid_pages(form_fill_path)

      expect(result).to eq("/tmp/#{notice_of_disagreement.id}-overlaid-form-fill-tmp.pdf")
    end
  end

  describe '#add_additional_pages' do
    it 'returns a Prawn::Document' do
      result = described_class.new(notice_of_disagreement).add_additional_pages
      expect(result.class).to eq(Prawn::Document)
    end

    it 'has 2 pages' do
      result = described_class.new(notice_of_disagreement).add_additional_pages
      expect(result.page_count).to eq(2)
    end
  end

  describe '#final_page_adjustments' do
    it 'returns nil when no additional pages are needed' do
      min_notice_of_disagreement = create(:minimal_notice_of_disagreement_v2)
      result = described_class.new(min_notice_of_disagreement).final_page_adjustments
      expect(result).to be_nil
    end

    it 'returns an array of rearranged pages' do
      result = described_class.new(notice_of_disagreement).final_page_adjustments
      expect(result).to eq [1, '4-end', '2-3']
    end
  end
end

module AppealsApi
  module PdfConstruction
    module NoticeOfDisagreement
      module V2
        describe Structure do
          include_examples 'notice of disagreements v2 and v3 structure examples'

          describe 'form_title' do
            it 'returns the NOD doc title' do
              expect(described_class.new(notice_of_disagreement).form_title).to eq('10182_v2')
            end
          end
        end
      end
    end
  end
end
