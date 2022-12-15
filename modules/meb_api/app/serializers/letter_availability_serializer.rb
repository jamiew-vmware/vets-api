# frozen_string_literal: true

class LetterAvailabilitySerializer < ActiveModel::Serializer
  attribute :is_available

  def id
    nil
  end
end
