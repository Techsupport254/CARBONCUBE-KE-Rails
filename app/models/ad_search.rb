class AdSearch < ApplicationRecord
  belongs_to :buyer, optional: true

  validates :search_term, presence: true

end
