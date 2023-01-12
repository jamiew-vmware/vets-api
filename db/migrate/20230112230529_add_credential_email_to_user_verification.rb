class AddCredentialEmailToUserVerification < ActiveRecord::Migration[6.1]
  def change
    safety_assured do
      add_reference :user_verifications, :user_credential_emails, foreign_key: true, null: true, index: true
    end
  end
end
