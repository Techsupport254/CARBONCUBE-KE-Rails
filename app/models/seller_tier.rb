class SellerTier < ApplicationRecord
  belongs_to :seller
  belongs_to :tier

  def subscription_countdown
    # Check if the tier is free (tier_id = 1)
    if tier_id == 1
      # Free tier never expires
      return { never_expires: true }
    else
      expiration_date = updated_at + duration_months.months
    end

    remaining_time = expiration_date - Time.current

    if remaining_time > 0
      {
        months: (remaining_time / 1.month).to_i,
        weeks: (remaining_time % 1.month / 1.week).to_i,
        days: (remaining_time % 1.week / 1.day).to_i,
        hours: (remaining_time % 1.day / 1.hour).to_i,
        minutes: (remaining_time % 1.hour / 1.minute).to_i,
        seconds: (remaining_time % 1.minute).to_i
      }
    else
      { expired: true }
    end
  end
end
