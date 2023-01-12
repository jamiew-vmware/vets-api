class CreateUserCredentialEmail < ActiveRecord::Migration[6.1]
  def change
    create_table :user_credential_emails do |t|
      t.text :credential_email_ciphertext
      t.text :encrypted_kms_key
      t.timestamps
    end
  end
end
