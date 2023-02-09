# frozen_string_literal: true

require 'rails_helper'
require_relative '../shared_hlr_pdf_construction_examples'

module AppealsApi
  module PdfConstruction
    module HigherLevelReview
      module V3
        describe FormFields do
          include_examples 'shared HLR v2 and v3 form fields examples'
        end
      end
    end
  end
end
