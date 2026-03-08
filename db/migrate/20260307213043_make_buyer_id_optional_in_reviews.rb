class MakeBuyerIdOptionalInReviews < ActiveRecord::Migration[7.1]
  def change
    change_column_null :reviews, :buyer_id, true
  end
end
