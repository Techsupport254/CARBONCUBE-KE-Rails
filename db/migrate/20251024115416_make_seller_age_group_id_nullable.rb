class MakeSellerAgeGroupIdNullable < ActiveRecord::Migration[7.1]
  def change
    change_column_null :sellers, :age_group_id, true
  end
end

