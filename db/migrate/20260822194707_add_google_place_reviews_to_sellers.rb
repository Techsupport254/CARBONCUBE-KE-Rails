class AddGooglePlaceReviewsToSellers < ActiveRecord::Migration[7.1]
  def change
    change_table :sellers, bulk: true do |t|
      t.string :google_place_id
      t.jsonb :google_place_reviews, default: []
      t.datetime :google_reviews_fetched_at
      t.datetime :google_place_id_fetched_at

      t.index :google_place_id
    end
  end
end
