class ClickEventSerializer < ActiveModel::Serializer
  attributes :id, :event_type, :ad_id, :buyer_id, :metadata, :created_at, :updated_at

  # Optional: Include associated ad and user details
  belongs_to :ad, if: -> { object.ad.present? }
  belongs_to :buyer, if: -> { object.buyer.present? }

  # Example of custom serialization for metadata
  attribute :metadata do
    object.metadata || {}
  end

  # Example of custom formatting for `created_at`
  attribute :formatted_created_at do
    object.created_at.strftime('%Y-%m-%d %H:%M:%S')
  end
end
