class Payment < ApplicationRecord
  validates :trans_id, presence: true, uniqueness: true
  validates :trans_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
end
