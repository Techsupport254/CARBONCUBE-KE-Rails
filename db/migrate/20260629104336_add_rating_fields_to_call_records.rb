class AddRatingFieldsToCallRecords < ActiveRecord::Migration[7.1]
  def change
    add_column :call_records, :rating_token, :string
    add_column :call_records, :customer_email, :string
    add_column :call_records, :customer_rating, :integer
    add_column :call_records, :customer_feedback, :text
    add_column :call_records, :rating_submitted_at, :datetime
  end
end
