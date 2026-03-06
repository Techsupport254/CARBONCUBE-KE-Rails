class MobileRelease < ApplicationRecord
  validates :version_name, :abi, :download_url, presence: true

  scope :active, -> { where(active: true) }
  scope :stable, -> { where(is_stable: true) }

  def self.latest_release
    active.order(created_at: :desc).first
  end

  def self.all_latest_by_abi
    # Grouped by ABI, get the most recent one for each
    active.order(created_at: :desc).group_by(&:abi).map { |abi, releases| releases.first }
  end
end
