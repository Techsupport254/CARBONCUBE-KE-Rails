class SalesUserFieldLocation < ApplicationRecord
  belongs_to :sales_user

  validates :latitude, presence: true, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }
  validates :longitude, presence: true, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }
  validates :check_in_date, presence: true
  validates :check_in_date, uniqueness: { scope: :sales_user_id }

  scope :today, -> { where(check_in_date: Date.current) }
  scope :for_date, ->(date) { where(check_in_date: date) }
  scope :recent, ->(limit = 30) { order(created_at: :desc).limit(limit) }
end
