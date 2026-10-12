# frozen_string_literal: true

class Sales::AppInstallsController < ApplicationController
  before_action :authenticate_sales_user

  # GET /sales/app_installs
  def index
    page = [params[:page].to_i, 1].max
    per_page = params[:per_page].present? ? [params[:per_page].to_i, 100].min : 25
    user_type_filter = params[:user_type].to_s.strip.downcase
    platform_filter = params[:platform].to_s.strip.downcase
    query = params[:query].to_s.strip

    mobile_tokens = DeviceToken.where(platform: %w[android ios])

    # Overall KPIs
    total_installs = mobile_tokens.count
    sellers_with_app = DeviceToken.where(user_type: 'Seller', platform: %w[android ios]).select(:user_id).distinct.count
    total_sellers = Seller.where(deleted: false).count
    seller_adoption_pct = total_sellers.positive? ? (sellers_with_app.to_f / total_sellers * 100).round(1) : 0

    buyers_with_app = DeviceToken.where(user_type: 'Buyer', platform: %w[android ios]).select(:user_id).distinct.count
    total_buyers = Buyer.where(deleted: false).count
    buyer_adoption_pct = total_buyers.positive? ? (buyers_with_app.to_f / [total_buyers, 1].max * 100).round(1) : 0

    sales_staff_with_app = DeviceToken.where(user_type: 'SalesUser', platform: %w[android ios]).select(:user_id).distinct.count
    guests_count = DeviceToken.where(user_id: nil, platform: %w[android ios]).count
    android_count = mobile_tokens.where(platform: 'android').count
    ios_count = mobile_tokens.where(platform: 'ios').count
    active_7d = mobile_tokens.where('updated_at >= ?', 7.days.ago).count
    active_30d = mobile_tokens.where('updated_at >= ?', 30.days.ago).count

    kpis = {
      total_installs: total_installs,
      unique_users: sellers_with_app + buyers_with_app + sales_staff_with_app,
      sellers_count: sellers_with_app,
      total_sellers: total_sellers,
      seller_adoption_pct: seller_adoption_pct,
      buyers_count: buyers_with_app,
      total_buyers: total_buyers,
      buyer_adoption_pct: buyer_adoption_pct,
      sales_staff_count: sales_staff_with_app,
      guests_count: guests_count,
      android_count: android_count,
      ios_count: ios_count,
      active_7d: active_7d,
      active_30d: active_30d
    }

    # Build filtered tokens query
    tokens_query = mobile_tokens.order(updated_at: :desc)

    case user_type_filter
    when 'seller', 'sellers'
      tokens_query = tokens_query.where(user_type: 'Seller')
    when 'buyer', 'buyers'
      tokens_query = tokens_query.where(user_type: 'Buyer')
    when 'guest', 'guests'
      tokens_query = tokens_query.where(user_id: nil)
    when 'sales_user', 'sales', 'staff'
      tokens_query = tokens_query.where(user_type: 'SalesUser')
    end

    if %w[android ios].include?(platform_filter)
      tokens_query = tokens_query.where(platform: platform_filter)
    end

    # Search filter
    if query.present?
      matching_seller_ids = Seller.where(
        "enterprise_name ILIKE :q OR fullname ILIKE :q OR email ILIKE :q OR phone_number ILIKE :q",
        q: "%#{query}%"
      ).pluck(:id)

      matching_buyer_ids = Buyer.where(
        "fullname ILIKE :q OR username ILIKE :q OR email ILIKE :q OR phone_number ILIKE :q",
        q: "%#{query}%"
      ).pluck(:id)

      matching_sales_ids = SalesUser.where(
        "fullname ILIKE :q OR email ILIKE :q OR phone_number ILIKE :q",
        q: "%#{query}%"
      ).pluck(:id)

      tokens_query = tokens_query.where(
        "(user_type = 'Seller' AND user_id IN (:seller_ids)) OR " \
        "(user_type = 'Buyer' AND user_id IN (:buyer_ids)) OR " \
        "(user_type = 'SalesUser' AND user_id IN (:sales_ids))",
        seller_ids: matching_seller_ids,
        buyer_ids: matching_buyer_ids,
        sales_ids: matching_sales_ids
      )
    end

    total_count = tokens_query.count
    paginated_tokens = tokens_query.limit(per_page).offset((page - 1) * per_page).includes(:user).to_a

    records = paginated_tokens.map do |dt|
      user = dt.user
      name = 'Guest Device'
      contact_person = nil
      email = nil
      phone = nil
      avatar = nil
      shop_slug = nil
      verified = false

      if user.is_a?(Seller)
        name = user.enterprise_name.presence || user.fullname.presence || 'Seller'
        contact_person = user.fullname
        email = user.email
        phone = user.phone_number
        avatar = user.profile_picture.presence || (user.respond_to?(:banner_url) ? user.banner_url : nil)
        shop_slug = user.slug
        verified = user.respond_to?(:seller_verification) && user.seller_verification&.verified? || false
      elsif user.is_a?(Buyer)
        name = user.username.presence || user.fullname.presence || 'Buyer'
        contact_person = user.fullname
        email = user.email
        phone = user.phone_number
        avatar = user.profile_picture
      elsif user.is_a?(SalesUser)
        name = user.fullname.presence || 'Sales Staff'
        email = user.email
        phone = user.phone_number
        avatar = user.profile_picture
      end

      {
        id: dt.id,
        token_prefix: "#{dt.token.to_s.first(16)}...",
        platform: dt.platform,
        user_type: dt.user_type || 'Guest',
        user_id: dt.user_id,
        name: name,
        contact_person: contact_person,
        email: email,
        phone: phone,
        avatar: avatar,
        shop_slug: shop_slug,
        verified: verified,
        created_at: dt.created_at,
        updated_at: dt.updated_at,
        last_active_at: dt.updated_at
      }
    end

    render json: {
      success: true,
      kpis: kpis,
      installs: records,
      pagination: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil
      }
    }
  end

  private

  def authenticate_sales_user
    @current_sales_user = SalesAuthorizeApiRequest.new(request.headers).result
    unless @current_sales_user
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end
end
