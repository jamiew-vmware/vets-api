# frozen_string_literal: true

module Mobile
  module V0
    class LettersSerializer
      include FastJsonapi::ObjectSerializer

      set_type :letters
      attributes :letters

      def initialize(id, letters, options = {})
        if letters.instance_of?(Hash)
          binding.pry
          letters = letters.map do |letter|
            letter[:letter_type] = letter[:letter_type].downcase

            letter[:letter_name] = case letter[:letter_type]
                                   when 'benefit_summary'
                                     letter[:letter_name] = 'Benefit Summary and Service Verification Letter'
                                   when 'benefit_summary_dependent'
                                     letter[:letter_name] = 'Dependent Benefit Summary and Service Verification Letter'
                                   else
                                     letter[:letter_name]
                                   end

            Mobile::V0::Letter.new(letter[:letter_name], letter[:letter_type])
          end
          super(resource, options)

        else
          letters.map! do |letter|
            letter.name = 'Benefit Summary and Service Verification Letter' if letter.letter_type == 'benefit_summary'
            if letter.letter_type == 'benefit_summary_dependent'
              letter.name = 'Dependent Benefit Summary and Service Verification Letter'
            end
            letter
          end
          resource = LettersStruct.new(id, letters)
        end
        super(resource, options)
      end
    end

    LettersStruct = Struct.new(:id, :letters)
  end
end
