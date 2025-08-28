class BuyForMeOrderSeller < ApplicationRecord
  belongs_to :buy_for_me_order
  belongs_to :seller
end