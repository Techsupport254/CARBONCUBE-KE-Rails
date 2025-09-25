class ChangeCityToNullableInBuyers < ActiveRecord::Migration[7.1]
  def change
    change_column_null :buyers, :city, true
  end
end
