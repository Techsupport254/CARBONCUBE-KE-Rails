class CreateJoinTableCategoriesSellers < ActiveRecord::Migration[7.1]
  def change
    create_join_table :sellers, :categories do |t|
      t.index [:seller_id, :category_id]
      t.index [:category_id, :seller_id]
      
    end
  end
end
