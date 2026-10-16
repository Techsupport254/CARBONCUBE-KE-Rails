# frozen_string_literal: true

class Sales::AppInstallsController < ApplicationController
  before_action :authenticate_sales_user

  # GET /sales/app_installs
  def index
    page = [params[:page].to_i, 1].max
    per_page = params[:per_page].present? ? [params[:per_page].to_i, 200].min : 100
    user_type_filter = params[:user_type].to_s.strip.downcase
    platform_filter = params[:platform].to_s.strip.downcase
    query = params[:query].to_s.strip
    sort_by = params[:sort_by].to_s.strip.downcase
    sort_dir = params[:sort_dir].to_s.strip.downcase == 'asc' ? :asc : :desc

    mobile_tokens = DeviceToken.where(platform: %w[android ios])
    kpis = DeviceToken.mobile_app_kpis

    # Build filtered tokens query
    tokens_query = mobile_tokens

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

    # Apply ordering - default to date installed (created_at: :desc)
    ordered_tokens_query = case sort_by
                           when 'last_active', 'last_active_at', 'updated_at'
                             tokens_query.order(updated_at: sort_dir)
                           when 'platform'
                             tokens_query.order(platform: sort_dir, created_at: :desc)
                           when 'user_type', 'account_type'
                             tokens_query.order(user_type: sort_dir, created_at: :desc)
                           when 'created_at', 'installed_at', 'date_installed'
                             tokens_query.order(created_at: sort_dir)
                           else
                             tokens_query.order(created_at: :desc)
                           end

    total_count = tokens_query.count
    paginated_tokens = ordered_tokens_query.limit(per_page).offset((page - 1) * per_page).includes(:user).to_a

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
