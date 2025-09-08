class BestSellersCache < ApplicationRecord
  validates :cache_key, presence: true, uniqueness: true
  validates :data, presence: true
  validates :expires_at, presence: true

  scope :valid, -> { where('expires_at > ?', Time.current) }
  scope :expired, -> { where('expires_at <= ?', Time.current) }

  def self.get(key)
    cache_entry = valid.find_by(cache_key: key)
    return nil unless cache_entry
    
    cache_entry.data
  end

  def self.set(key, data, expires_in: 30.minutes)
    expires_at = Time.current + expires_in
    
    cache_entry = find_or_initialize_by(cache_key: key)
    cache_entry.update!(
      data: data,
      expires_at: expires_at
    )
    
    data
  end

  def self.delete_expired
    expired.delete_all
  end

  def expired?
    expires_at <= Time.current
  end
end
