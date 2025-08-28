class About < ApplicationRecord
  # Validations
  validates :description, presence: true
  validates :mission, presence: true
  validates :vision, presence: true
  validates :why_choose_us, presence: true
  validates :image_url, presence: true

  # Ensure values is an array of strings
  validate :validate_values

  private

  def validate_values
    errors.add(:values, 'must be an array of strings') unless values.is_a?(Array) && values.all? { |v| v.is_a?(String) }
  end
end
