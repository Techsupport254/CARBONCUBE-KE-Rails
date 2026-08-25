class AddUniqueIndexToSalesHolidays < ActiveRecord::Migration[7.1]
  def change
    add_index :sales_holidays, [:date, :name], unique: true
  end
end
