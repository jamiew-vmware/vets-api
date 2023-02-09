# frozen_string_literal: true

require 'rails_helper'
require_relative '../shared_hlr_pdf_construction_examples'

module AppealsApi
  module PdfConstruction
    module HigherLevelReview
      module V3
        describe Structure do
          include_examples 'shared HLR v2 and v3 structure examples'

          describe 'form_title' do
            it 'returns the HLR doc title' do
              expect(described_class.new(higher_level_review).form_title).to eq('200996_v3')
            end
          end
        end
      end
    end
  end
end
