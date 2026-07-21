class ChangeReviewsSellerIdToUuid < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    # Remove old indexes (two indexes exist on seller_id)
    remove_index :reviews, name: :index_reviews_on_seller_id if index_name_exists?(:reviews, 'index_reviews_on_seller_id')
    remove_index :reviews, name: :index_reviews_seller_id if index_name_exists?(:reviews, 'index_reviews_seller_id')

    # Cast string column to uuid
    execute <<-SQL
      ALTER TABLE reviews
      ALTER COLUMN seller_id TYPE uuid
      USING seller_id::uuid;
    SQL

    add_index :reviews, :seller_id, algorithm: :concurrently
  end

  def down
    remove_index :reviews, :seller_id if index_exists?(:reviews, :seller_id)

    execute <<-SQL
      ALTER TABLE reviews
      ALTER COLUMN seller_id TYPE string
      USING seller_id::text;
    SQL

    add_index :reviews, :seller_id
  end
end
