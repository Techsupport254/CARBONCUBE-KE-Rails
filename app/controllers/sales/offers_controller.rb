class Sales::OffersController < ApplicationController
  before_action :authenticate_sales_user
  
  # GET /sales/offers/offer_types
  def offer_types
    types = Offer.offer_types.keys.map do |type|
      {
        value: type,
        label: type.titleize,
        description: get_offer_type_description(type)
      }
    end

    render json: { offer_types: types }
  end

  private

  def authenticate_sales_user
    @current_sales_user = SalesAuthorizeApiRequest.new(request.headers).result
    unless @current_sales_user
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end

  def get_offer_type_description(type)
    descriptions = {
      'flash_sale' => 'Short-duration sales (hours/days)',
      'limited_time_offer' => 'Any time-limited promotion',
      'daily_deal' => 'Daily special offers',
      'weekend_sale' => 'Weekend-specific promotions',
      'monthly_special' => 'Monthly promotional offers',
      'black_friday' => 'Black Friday sales',
      'cyber_monday' => 'Cyber Monday tech deals',
      'boxing_day' => 'Boxing Day sales',
      'new_year' => 'New Year promotions',
      'easter' => 'Easter sales',
      'christmas' => 'Christmas promotions',
      'independence_day' => 'Jamhuri Day / Madaraka Day',
      'end_of_year' => 'End of year clearance',
      'mid_year_sale' => 'Mid-year promotions',
      'clearance' => 'Clearance sale',
      'stock_clearance' => 'Stock liquidation',
      'overstock_sale' => 'Excess inventory sale',
      'warehouse_sale' => 'Warehouse clearance',
      'discontinued_items' => 'Discontinued product sale',
      'new_arrival' => 'New product launch',
      'new_stock' => 'Newly stocked items',
      'restocked_items' => 'Back in stock',
      'exclusive_items' => 'Exclusive products',
      'imported_goods' => 'Imported items sale',
      'bulk_discount' => 'Volume/bulk discounts',
      'wholesale_pricing' => 'Wholesale rates',
      'trade_discount' => 'Trade/contractor discounts',
      'business_special' => 'B2B exclusive offers',
      'contract_pricing' => 'Special contract rates',
      'loyalty_reward' => 'Repeat customer rewards',
      'first_time_buyer' => 'New customer welcome',
      'vip_offer' => 'VIP customer exclusive',
      'referral_bonus' => 'Referral incentives',
      'free_shipping' => 'Free delivery offer',
      'free_installation' => 'Free installation service',
      'bundle_deal' => 'Package deals',
      'combo_offer' => 'Combo packages',
      'buy_more_save_more' => 'Tiered volume discounts',
      'custom' => 'Seller-defined custom offer'
    }

    descriptions[type] || type.titleize
  end
end
