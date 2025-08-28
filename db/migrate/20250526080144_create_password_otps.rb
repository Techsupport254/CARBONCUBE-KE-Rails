class CreatePasswordOtps < ActiveRecord::Migration[7.0]
  def change
    create_table :password_otps do |t|
      t.string :otp_digest, null: false
      t.datetime :otp_sent_at, null: false
      t.string :otp_purpose, null: false, default: 'password_reset'
      t.references :otpable, polymorphic: true, null: false

      t.timestamps
    end

    add_index :password_otps, [:otpable_type, :otpable_id]
  end
end
