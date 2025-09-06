class SellerTierSerializer < ActiveModel::Serializer
  attributes :id, :seller_id, :tier_id, :duration_months, :created_at, :updated_at, :subscription_countdown, :subscription_expiry_date

  def subscription_countdown
    object.subscription_countdown
  end

  def subscription_expiry_date
    expiry_date = object.expires_at || (object.updated_at + object.duration_months.months)
    expiry_date.iso8601
  end
end
