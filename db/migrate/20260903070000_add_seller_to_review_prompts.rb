# frozen_string_literal: true

class AddSellerToReviewPrompts < ActiveRecord::Migration[7.1]
  def change
    change_column_null :review_prompts, :buyer_id, true

    add_reference :review_prompts, :seller, null: true, type: :uuid, foreign_key: true, index: false
    add_index :review_prompts, %i[seller_id ad_id], unique: true
  end
end
