class MakeAgeGroupIdOptionalForBuyers < ActiveRecord::Migration[7.1]
  def change
    change_column_null :buyers, :age_group_id, true
  end
end
