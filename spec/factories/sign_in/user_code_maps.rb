# frozen_string_literal: true

FactoryBot.define do
  factory :user_code_map, class: 'SignIn::UserCodeMap' do
    skip_create

    login_code { SecureRandom.uuid }
    type { SignIn::Constants::Auth::CSP_TYPES.first }
    client_state { SecureRandom.hex }
    client_id { create(:client_config).client_id }

    initialize_with do
      new(login_code: login_code,
          client_state: client_state,
          client_id: client_id,
          type: type)
    end
  end
end
