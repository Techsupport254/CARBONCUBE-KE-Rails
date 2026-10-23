# Tracks who soft-deleted an ad ('seller' | 'sales' | 'admin') and when.
# Hard destroys (account deletion cascade, console) leave no row to annotate.
class AddDeletedAttributionToAds < ActiveRecord::Migration[7.1]
  def change
    change_table :ads, bulk: true do |t|
      t.datetime :deleted_at
      t.string :deleted_by
    end
  end
end
