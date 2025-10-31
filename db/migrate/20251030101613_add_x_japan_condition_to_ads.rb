class AddXJapanConditionToAds < ActiveRecord::Migration[7.1]
  def up
    # Note: No database schema change needed - condition is stored as integer
    # This migration documents the addition of x_japan: 3 to the enum
    # The enum definition is updated in app/models/ad.rb
  end

  def down
    # No rollback needed - enum can be reverted in model
  end
end
