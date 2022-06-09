# frozen_string_literal: true

module SignIn
  class CodeChallengeStateMapper
    attr_reader :code_challenge, :code_challenge_method, :client_id, :client_state

    def initialize(code_challenge:, code_challenge_method:, client_id:, client_state: nil)
      @code_challenge = code_challenge
      @code_challenge_method = code_challenge_method
      @client_id = client_id
      @client_state = client_state
    end

    def perform
      check_code_challenge_method
      map_code_challenge_to_state
      state
    end

    private

    def check_code_challenge_method
      if code_challenge_method != Constants::Auth::CODE_CHALLENGE_METHOD
        raise Errors::CodeChallengeMethodMismatchError, 'Code Challenge Method is not valid'
      end
    end

    def map_code_challenge_to_state
      CodeChallengeStateMap.new(code_challenge: remove_base64_padding(code_challenge),
                                state: state,
                                client_id: client_id,
                                client_state: client_state).save!
    rescue Common::Exceptions::ValidationErrors
      raise Errors::CodeChallengeStateMapError, 'Code Challenge or State or Client id is not valid'
    end

    def state
      @state ||= SecureRandom.hex
    end

    def remove_base64_padding(data)
      Base64.urlsafe_encode64(Base64.urlsafe_decode64(data.to_s), padding: false)
    rescue ArgumentError
      raise Errors::CodeChallengeMalformedError, 'Code Challenge is not valid'
    end
  end
end
