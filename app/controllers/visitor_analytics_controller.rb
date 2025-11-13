class VisitorAnalyticsController < ApplicationController
  before_action :authenticate_sales_user, only: [:analytics, :visitors_list, :visitor_click_events]
  skip_before_action :verify_authenticity_token, only: [:track_visitor]

  def authenticate_sales_user
    SalesAuthorizeApiRequest.new(request.headers).result
  rescue
    nil
  end

  def track_visitor
    visitor_tracking_service = VisitorTrackingService.new(request)
    visitor = visitor_tracking_service.track_visitor

    if visitor
      render json: {
        success: true,
        message: 'Visitor tracked successfully',
        visitor_id: visitor.visitor_id,
        is_new_visitor: visitor.visit_count == 1
      }, status: :ok
    else
      render json: {
        success: false,
        message: 'Visitor tracking skipped or failed'
      }, status: :ok
    end
  end

  def analytics
    date_filter = extract_date_filter

    visitor_metrics = {
      total_unique_visitors: Visitor.unique_visitors_count(date_filter),
      new_visitors: Visitor.new_visitors_count(date_filter),
      returning_visitors: Visitor.returning_visitors_count(date_filter),
      visitors_with_ad_clicks: Visitor.external_users.with_ad_clicks.count,
      registered_visitors: Visitor.external_users.registered.count,
      conversion_rate: Visitor.conversion_rate
    }

    visitors_by_source = Visitor.visitors_by_source(date_filter)
    visitors_by_utm_source = Visitor.visitors_by_utm_source(date_filter)

    # Determine granularity based on date filter
    # If filtering for today only, use hourly grouping; otherwise use daily
    if date_filter && date_filter[:start_date] == date_filter[:end_date] && 
       date_filter[:start_date] == Date.today
      # Hourly grouping for today - use database-agnostic approach
      today_start = Date.today.beginning_of_day
      today_end = Date.today.end_of_day
      
      # Get all visitors for today and group by hour manually
      today_visitors = Visitor.external_users
                              .where(first_visit_at: today_start..today_end)
                              .pluck(:first_visit_at)
      
      # Group by hour - include all 24 hours even if count is 0
      visitor_trends = {}
      (0..23).each do |hour|
        hour_start = today_start + hour.hours
        hour_end = hour_start + 1.hour
        count = today_visitors.count { |timestamp| timestamp >= hour_start && timestamp < hour_end }
        visitor_trends[hour_start.strftime("%Y-%m-%d %H:00:00")] = count
      end
    else
      # Daily grouping for other periods
      visitor_trends = Visitor.external_users
                              .group("DATE(first_visit_at)")
                              .order("DATE(first_visit_at)")
                              .count
    end

    render json: {
      visitor_metrics: visitor_metrics,
      visitors_by_source: visitors_by_source,
      visitors_by_utm_source: visitors_by_utm_source,
      visitor_trends: visitor_trends,
      date_filter: date_filter
    }
  rescue StandardError => e
    Rails.logger.error "Visitor analytics failed: #{e.message}"
    render json: { error: 'Analytics retrieval failed' }, status: :internal_server_error
  end

  def visitors_list
    date_filter = extract_date_filter
    page = [(params[:page] || 1).to_i, 1].max # Ensure page is at least 1
    per_page = [(params[:per_page] || 50).to_i, 1].max # Ensure per_page is at least 1
    per_page = [per_page, 100].min # Cap at 100 per page

    offset = [(page - 1) * per_page, 0].max # Ensure offset is never negative

    visitors = Visitor.external_users
                     .includes(:registered_user)
                     .date_filtered(date_filter)
                     .order(last_visit_at: :desc)
                     .limit(per_page)
                     .offset(offset)

    total_count = Visitor.external_users.date_filtered(date_filter).count

    visitor_data = visitors.map.with_index(offset + 1) do |visitor, index|
      user_details = if visitor.registered_user
        case visitor.registered_user_type
        when 'Buyer'
          {
            id: visitor.registered_user.id,
            fullname: visitor.registered_user.fullname,
            username: visitor.registered_user.username,
            email: visitor.registered_user.email,
            phone_number: visitor.registered_user.phone_number,
            profile_picture: visitor.registered_user.profile_picture,
            user_type: 'buyer'
          }
        when 'Seller'
          {
            id: visitor.registered_user.id,
            fullname: visitor.registered_user.fullname,
            username: visitor.registered_user.username,
            email: visitor.registered_user.email,
            phone_number: visitor.registered_user.phone_number,
            enterprise_name: visitor.registered_user.enterprise_name,
            user_type: 'seller'
          }
        else
          nil
        end
      else
        nil
      end

      {
        id: visitor.id,
        visitor_id: visitor.visitor_id,
        first_visit_at: visitor.first_visit_at,
        last_visit_at: visitor.last_visit_at,
        visit_count: visitor.visit_count,
        first_source: visitor.first_source,
        country: visitor.country,
        city: visitor.city,
        has_clicked_ad: visitor.has_clicked_ad,
        ad_click_count: visitor.ad_click_count,
        registered_user_type: visitor.registered_user_type,
        is_registered: visitor.registered_user_id.present?,
        user_details: user_details,
        row_number: index
      }
    end

    render json: {
      visitors: visitor_data,
      total_count: total_count,
      page: page,
      per_page: per_page,
      total_pages: (total_count.to_f / per_page).ceil
    }
  rescue StandardError => e
    Rails.logger.error "Visitor list failed: #{e.message}"
    render json: { error: 'Visitor list retrieval failed' }, status: :internal_server_error
  end

  def visitor_click_events
    visitor_id = params[:visitor_id]
    return render json: { error: 'Visitor ID required' }, status: :bad_request unless visitor_id.present?

    visitor = Visitor.find_by(visitor_id: visitor_id)
    return render json: { error: 'Visitor not found' }, status: :not_found unless visitor

    # Get all click events for this visitor by device_hash
    click_events = ClickEvent
      .where("metadata->>'device_hash' = ?", visitor_id)
      .excluding_internal_users
      .includes(:ad, :buyer)
      .order(:created_at)

    events_data = click_events.map do |event|
      metadata = event.metadata || {}
      contact_interaction = if metadata['action'] == 'seller_contact_interaction'
        {
          action_type: metadata['action_type'],
          contact_type: metadata['contact_type'],
          phone_number: metadata['phone_number'],
          location: metadata['location']
        }
      else
        nil
      end

      {
        id: event.id,
        event_type: event.event_type,
        ad_id: event.ad_id,
        ad_title: event.ad&.title,
        ad_image_url: event.ad&.first_valid_media_url,
        created_at: event.created_at,
        buyer_id: event.buyer_id,
        buyer_info: event.buyer ? {
          id: event.buyer.id,
          name: event.buyer.fullname,
          email: event.buyer.email,
          username: event.buyer.username,
          phone: event.buyer.phone_number
        } : nil,
        user_info: metadata['user_id'] ? {
          id: metadata['user_id'],
          role: metadata['user_role'],
          email: metadata['user_email'],
          username: metadata['user_username']
        } : nil,
        was_authenticated: metadata['was_authenticated'] || false,
        is_guest: metadata['is_guest'] != false,
        converted_from_guest: metadata['converted_from_guest'] || false,
        triggered_login_modal: metadata['triggered_login_modal'] || false,
        post_login_reveal: metadata['post_login_reveal'] || false,
        contact_interaction: contact_interaction
      }
    end

    render json: {
      visitor_id: visitor_id,
      click_events: events_data,
      total_count: events_data.count
    }
  rescue StandardError => e
    Rails.logger.error "Visitor click events failed: #{e.message}"
    render json: { error: 'Click events retrieval failed' }, status: :internal_server_error
  end

  # GET /visitor/:visitor_id
  def visitor_details
    visitor_id = params[:visitor_id]
    return render json: { error: 'Visitor ID required' }, status: :bad_request unless visitor_id.present?

    visitor = Visitor.find_by(visitor_id: visitor_id)
    return render json: { error: 'Visitor not found' }, status: :not_found unless visitor

    render json: {
      visitor: {
        id: visitor.id,
        visitor_id: visitor.visitor_id,
        first_visit_at: visitor.first_visit_at,
        last_visit_at: visitor.last_visit_at,
        visit_count: visitor.visit_count,
        first_source: visitor.first_source,
        country: visitor.country,
        city: visitor.city,
        region: visitor.region,
        timezone: visitor.timezone,
        has_clicked_ad: visitor.has_clicked_ad,
        ad_click_count: visitor.ad_click_count,
        first_ad_click_at: visitor.first_ad_click_at,
        last_ad_click_at: visitor.last_ad_click_at,
        is_registered: visitor.registered_user_id.present?,
        registered_user_type: visitor.registered_user_type,
        registered_user_id: visitor.registered_user_id,
        ip_address: visitor.ip_address,
        is_internal_user: visitor.is_internal_user
      }
    }
  rescue StandardError => e
    Rails.logger.error "Visitor details failed: #{e.message}"
    render json: { error: 'Visitor details retrieval failed' }, status: :internal_server_error
  end

  private

  def extract_date_filter
    return nil unless params[:start_date].present? && params[:end_date].present?

    begin
      {
        start_date: Date.parse(params[:start_date]),
        end_date: Date.parse(params[:end_date])
      }
    rescue ArgumentError
      nil
    end
  end
end
