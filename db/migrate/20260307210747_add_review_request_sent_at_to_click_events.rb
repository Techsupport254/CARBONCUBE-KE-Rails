class AddReviewRequestSentAtToClickEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :click_events, :review_request_sent_at, :datetime
  end
end
