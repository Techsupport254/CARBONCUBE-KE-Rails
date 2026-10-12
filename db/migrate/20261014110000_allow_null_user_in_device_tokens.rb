class AllowNullUserInDeviceTokens < ActiveRecord::Migration[7.1]
  def change
    change_column_null :device_tokens, :user_id, true
    change_column_null :device_tokens, :user_type, true
  end
end
