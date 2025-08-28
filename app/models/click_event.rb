class ClickEvent < ApplicationRecord
  belongs_to :buyer, optional: true
  belongs_to :ad, optional: true

  EVENT_TYPES = %w[Ad-Click Reveal-Seller-Details Add-to-Cart Add-to-Wish-List].freeze

  validates :event_type, presence: true, inclusion: { in: EVENT_TYPES }
  # validates :metadata, presence: true, if: -> { event_type == 'Reveal-Seller-Details' } # Example: require metadata for certain event types

  # Scope to find the most common click types
  scope :popular_events, ->(limit = 10) {
    group(:event_type).order('COUNT(event_type) DESC').limit(limit).count
  }

  # Scope to filter clicks by a specific ad
  scope :for_ad, ->(ad_id) { where(ad_id: ad_id) }
end
