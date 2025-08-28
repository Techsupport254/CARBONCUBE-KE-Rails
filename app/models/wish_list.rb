class WishList < ApplicationRecord
  belongs_to :buyer
  belongs_to :ad
end
