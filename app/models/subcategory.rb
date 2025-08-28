class Subcategory < ApplicationRecord
  belongs_to :category
  has_many :ads, dependent: :nullify # or :destroy

  validates :name, presence: true, uniqueness: { scope: :category_id }
end
