class Admin::FieldLocationsController < ApplicationController
  before_action :authenticate_admin

  # GET /admin/field_locations?date=2026-08-25
  # Returns all sales users' field location check-ins for a given date (default: today).
  # Includes users with no check-in (so admin can see who hasn't shared).
  def index
    date = params[:date].present? ? Date.parse(params[:date]) : FieldLocationRedisService.eat_today

    # All non-manager sales users
    sales_users = SalesUser.where(is_manager: [false, nil]).order(:fullname)

    # Field locations for the date
    locations = SalesUserFieldLocation.where(check_in_date: date)
                      .index_by(&:sales_user_id)

    # Also check Redis for live (not-yet-flushed) pings
    result = sales_users.map do |user|
      db_record = locations[user.id]
      redis_pings = FieldLocationRedisService.fetch_pings(user.id, date)

      if db_record
        {
          user_id: user.id,
          fullname: user.fullname,
          email: user.email,
          checked_in: true,
          ping_count: (db_record.pings&.size || 0) + redis_pings.size,
          latitude: db_record.latitude,
          longitude: db_record.longitude,
          display_name: db_record.display_name,
          area: db_record.area,
          city: db_record.city,
          county: db_record.county,
          country: db_record.country,
          notes: db_record.notes,
          first_ping_at: db_record.pings&.first&.dig('ts'),
          last_ping_at: db_record.pings&.last&.dig('ts'),
          pings: db_record.pings || []
        }
      elsif redis_pings.any?
        first = redis_pings.first
        {
          user_id: user.id,
          fullname: user.fullname,
          email: user.email,
          checked_in: true,
          ping_count: redis_pings.size,
          latitude: first['lat'],
          longitude: first['lng'],
          display_name: first['display_name'],
          area: first['area'],
          city: first['city'],
          county: first['county'],
          country: first['country'],
          notes: first['notes'],
          first_ping_at: first['ts'],
          last_ping_at: redis_pings.last['ts'],
          pings: redis_pings
        }
      else
        {
          user_id: user.id,
          fullname: user.fullname,
          email: user.email,
          checked_in: false,
          ping_count: 0,
          latitude: nil,
          longitude: nil,
          display_name: nil,
          area: nil,
          city: nil,
          county: nil,
          country: nil,
          notes: nil,
          first_ping_at: nil,
          last_ping_at: nil,
          pings: []
        }
      end
    end

    is_holiday = SalesHoliday.non_working_day?(date)

    render json: {
      date: date.iso8601,
      is_holiday: is_holiday,
      holiday_name: SalesHoliday.exemption_name(date),
      total_users: sales_users.size,
      checked_in_count: is_holiday ? sales_users.size : result.count { |r| r[:checked_in] },
      locations: result
    }
  end

  # GET /admin/field_locations/:user_id?date=2026-08-25
  # Returns a single user's detailed pings for a date
  def show
    date = params[:date].present? ? Date.parse(params[:date]) : FieldLocationRedisService.eat_today
    user = SalesUser.find_by(id: params[:user_id])

    return render json: { error: 'User not found' }, status: :not_found unless user

    db_record = SalesUserFieldLocation.find_by(sales_user_id: user.id, check_in_date: date)
    redis_pings = FieldLocationRedisService.fetch_pings(user.id, date)

    all_pings = (db_record&.pings || []) + redis_pings

    render json: {
      user: { id: user.id, fullname: user.fullname, email: user.email, is_manager: user.is_manager },
      date: date.iso8601,
      ping_count: all_pings.size,
      pings: all_pings,
      db_record: db_record&.as_json(only: %i[id latitude longitude display_name area city county country notes check_in_date created_at])
    }
  end

  # GET /admin/field_locations/assignments?date=2026-08-25
  # Returns carbon code assignments with sales user locations for anti-fraud verification.
  def assignments
    date = params[:date].present? ? Date.parse(params[:date]) : FieldLocationRedisService.eat_today

    assignments = SellerCarbonCodeAssignment
                    .includes(:seller, :sales_user, :carbon_code)
                    .where(created_at: date.all_day)
                    .order(created_at: :desc)

    result = assignments.map do |a|
      seller_branch = a.seller.branches.first
      seller_lat = seller_branch&.latitude
      seller_lng = seller_branch&.longitude

      # Determine verification status based on nearest ping distance
      nearest_dist = a.nearest_ping_distance_km
      verification = if nearest_dist.nil?
                       'pending' # No pings from this sales user on that day
                     elsif nearest_dist <= 5
                       'verified' # Sales user was within 5km of the seller
                     else
                       'suspicious' # Sales user was far away
                     end

      {
        id: a.id,
        assigned_at: a.created_at.iso8601,
        sales_user: { id: a.sales_user_id, fullname: a.sales_user&.fullname, email: a.sales_user&.email },
        seller: { id: a.seller_id, fullname: a.seller&.fullname, enterprise_name: a.seller&.enterprise_name,
                  location: a.seller&.location, city: a.seller&.city,
                  county: a.seller&.county&.name, latitude: seller_lat, longitude: seller_lng },
        carbon_code: a.carbon_code&.code,
        # Seller's GPS at registration (from their phone)
        seller_gps: {
          latitude: a.seller_gps_latitude,
          longitude: a.seller_gps_longitude,
          display_name: a.seller_gps_display_name
        },
        # Sales user's GPS (only if manually assigned — rare)
        sales_user_gps: (a.latitude.present? ? {
          latitude: a.latitude,
          longitude: a.longitude,
          display_name: a.display_name
        } : nil),
        # Cross-referenced nearest ping
        nearest_ping_distance_km: nearest_dist,
        nearest_ping_at: a.nearest_ping_at,
        verification: verification,
        notes: a.notes
      }
    end

    render json: {
      date: date.iso8601,
      total_assignments: result.size,
      assignments: result
    }
  end

  private

  def authenticate_admin
    @current_user = AdminAuthorizeApiRequest.new(request.headers).result
    return if @current_user.is_a?(Admin)

    render json: { error: 'Not Authorized' }, status: :unauthorized
  end
end
