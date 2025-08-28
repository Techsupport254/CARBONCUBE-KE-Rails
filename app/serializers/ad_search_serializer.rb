class AdSearchSerializer < ActiveModel::Serializer
  attributes :id, :search_term, :buyer_id, :created_at, :updated_at

  # Optional: Include user details if associated
  belongs_to :buyer, if: -> { object.buyer.present? }

  # Example of custom formatting for `created_at`
  attribute :formatted_created_at do
    object.created_at.strftime('%Y-%m-%d %H:%M:%S')
  end
end
