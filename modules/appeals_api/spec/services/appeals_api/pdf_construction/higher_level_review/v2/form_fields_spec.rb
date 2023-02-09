# frozen_string_literal: true

require 'rails_helper'
require_relative '../shared_hlr_pdf_construction_examples'

module AppealsApi
  module PdfConstruction
    module HigherLevelReview
      module V2
        describe FormFields do
          include_examples 'shared HLR v2 and v3 form fields examples'

          describe 'sso_ssoc_opt_in' do
            it { expect(described_class.new.sso_ssoc_opt_in).to eq 'form1[0].#subform[3].RadioButtonList[0]' }
          end
        end
      end
    end
  end
end
