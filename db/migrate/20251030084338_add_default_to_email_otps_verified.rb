class AddDefaultToEmailOtpsVerified < ActiveRecord::Migration[7.1]
  def up
    # Set default value for verified column
    change_column_default :email_otps, :verified, false
    
    # Update existing nil values to false
    EmailOtp.where(verified: nil).update_all(verified: false)
  end
  
  def down
    change_column_default :email_otps, :verified, nil
  end
end
