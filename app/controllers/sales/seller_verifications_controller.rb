class Sales::SellerVerificationsController < ApplicationController
  require 'csv'

  before_action :authenticate_sales_user
  before_action :set_seller, only: [:create]

  # GET /sales/seller_verifications
  # Leads & managers see team verifications; field reps see their own.
  def index
    page = [params[:page]&.to_i || 1, 1].max
    per_page = [params[:per_page]&.to_i || 20, 100].min

    scope = scoped_verifications
    scope = scope.where(outcome: params[:outcome]) if params[:outcome].present?
    scope = scope.where(sales_user_id: params[:sales_user_id]) if params[:sales_user_id].present? && @current_sales_user.team_sales_dashboard_access?
    scope = scope.where(seller_id: params[:seller_id]) if params[:seller_id].present?

    if params[:start_date].present?
      start_date = Date.parse(params[:start_date]) rescue nil
      scope = scope.where('seller_verifications.created_at >= ?', start_date.beginning_of_day) if start_date
    end
    if params[:end_date].present?
      end_date = Date.parse(params[:end_date]) rescue nil
      scope = scope.where('seller_verifications.created_at <= ?', end_date.end_of_day) if end_date
    end

    verifications = scope.includes(:seller, :sales_user).recent

    if params[:format] == 'csv'
      return send_data(
        build_verifications_csv(verifications),
        filename: "seller-verifications-#{Date.current}.csv",
        type: 'text/csv'
      )
    end

    verifications = verifications.offset((page - 1) * per_page).limit(per_page)
    total_count = scope.count

    render json: {
      verifications: verifications.map { |v| serialize_verification(v, include_relations: true) },
      pagination: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil
      }
    }
  end
  # POST /sales/sellers/:seller_id/verifications
  # Logs a field verification visit. Whitelisted corrections are applied to the
  # seller immediately (go live), and the old→new values are stored on the
  # verification for the manager audit trail.
  def create
    if params[:photo].present? && !params[:photo].content_type.to_s.start_with?('image/')
      return render json: { error: 'Photo must be an image' }, status: :unprocessable_entity
    end

    # Idempotency — the mobile queue replays a submission when its response is
    # lost to a timeout/disconnect. A matching client_token means the row (and
    # its photo, corrections, and notifications) already went through; return
    # it instead of creating a duplicate.
    if params[:client_token].present?
      existing = SellerVerification.find_by(client_token: params[:client_token])
      if existing
        return render json: {
          message: 'Verification logged',
          verification: serialize_verification(existing),
          seller: @seller.reload.as_json(only: [:id, :enterprise_name, :phone_number, :location, :county_id, :sub_county_id, :building, :room, :field_verified_at]),
          deduplicated: true
        }, status: :ok
      end
    end

    diff, updates = SellerVerification.build_corrections(@seller, params[:corrections])
    outcome = params[:outcome].presence_in(SellerVerification::OUTCOMES) ||
              (diff.any? ? 'corrected' : 'verified')
    photo_url = upload_shop_photo(params[:photo])

    # Building/room are current shop details, not just audit fields — persist
    # them on the seller so public pages can display the full physical address.
    building = params[:building]&.strip.presence
    room = params[:room]&.strip.presence
    updates[:building] = building if building
    updates[:room] = room if room

    verification = nil
    SellerVerification.transaction do
      @seller.update!(updates) if updates.present?

      verification = @seller.seller_verifications.create!(
        sales_user: @current_sales_user,
        outcome: outcome,
        photo_url: photo_url,
        location_confirmed: truthy?(params[:location_confirmed]),
        phone_confirmed: truthy?(params[:phone_confirmed]),
        business_name_confirmed: truthy?(params[:business_name_confirmed]),
        documents_confirmed: truthy?(params[:documents_confirmed]),
        corrections: diff,
        notes: params[:notes]&.strip&.presence,
        building: building,
        room: room,
        latitude: params[:latitude],
        longitude: params[:longitude],
        display_name: params[:display_name],
        accuracy_m: params[:accuracy_m],
        client_token: params[:client_token]
      )

      if verification.successful?
        @seller.update_column(:field_verified_at, verification.created_at)
        # The verified shop-front photo doubles as the public shop banner.
        @seller.update_column(:banner_url, photo_url) if photo_url.present?
      end

      # Optional follow-up/issue captured at visit time — e.g. "seller needs
      # help uploading ads, call back Friday". Lives on the seller with a link
      # back to this visit so it survives beyond the verification row.
      create_follow_up!(verification)
    end

    verification.assess_gps!
    sync_shop_coordinates!(verification) if verification.successful?
    SellerVerificationNotificationJob.perform_later(verification.id)

    render json: {
      message: 'Verification logged',
      verification: serialize_verification(verification),
      seller: @seller.reload.as_json(only: [:id, :enterprise_name, :phone_number, :location, :county_id, :sub_county_id, :building, :room, :field_verified_at])
    }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: 'Verification failed', details: e.record.errors.full_messages }, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotUnique
    # Two submissions raced with the same client_token — the unique index
    # guarantees only one row exists; return whichever committed.
    existing = SellerVerification.find_by(client_token: params[:client_token])
    if existing
      render json: {
        message: 'Verification logged',
        verification: serialize_verification(existing),
        seller: @seller.reload.as_json(only: [:id, :enterprise_name, :phone_number, :location, :county_id, :sub_county_id, :building, :room, :field_verified_at]),
        deduplicated: true
      }, status: :ok
    else
      render json: { error: 'Verification failed' }, status: :unprocessable_entity
    end
  end


  # GET /sales/seller_verifications/stats
  # Per-rep verification & correction stats for the manager dashboard.
  # Cached briefly — aggregates over the whole table are expensive and don't
  # need to be realtime.
  def stats
    cache_key = "seller_verification_stats_v1_#{stats_scope_key}"
    render json: Rails.cache.fetch(cache_key, expires_in: 2.minutes) { compute_stats }
  end

  private

  def authenticate_sales_user
    @current_sales_user = SalesAuthorizeApiRequest.new(request.headers).result
    unless @current_sales_user
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end

  def set_seller
    @seller = Seller.find_by(slug: params[:seller_id]) || Seller.find(params[:seller_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Seller not found' }, status: :not_found
  end

  def scoped_verifications
    if @current_sales_user.full_sales_dashboard_access?
      SellerVerification.all
    elsif @current_sales_user.team_sales_dashboard_access?
      SellerVerification.where(sales_user_id: team_scope_ids)
    else
      SellerVerification.where(sales_user_id: @current_sales_user.id)
    end
  end

  def team_scope_ids
    @team_scope_ids ||= [@current_sales_user.id] + @current_sales_user.team_members.pluck(:id)
  end

  # Cache keys differ per visibility scope, not per user — two managers share
  # the 'all' cache entry.
  def stats_scope_key
    if @current_sales_user.full_sales_dashboard_access?
      'all'
    elsif @current_sales_user.team_sales_dashboard_access?
      "team_#{@current_sales_user.id}"
    else
      "rep_#{@current_sales_user.id}"
    end
  end

  def compute_stats
    scope = scoped_verifications

    per_rep = scope.group(:sales_user_id).pluck(
      :sales_user_id,
      Arel.sql('COUNT(*)'),
      Arel.sql("COUNT(*) FILTER (WHERE outcome IN ('verified','corrected'))"),
      Arel.sql("COUNT(*) FILTER (WHERE corrections <> '{}'::jsonb)"),
      Arel.sql("COUNT(*) FILTER (WHERE gps_verdict = 'verified')"),
      Arel.sql("COUNT(*) FILTER (WHERE gps_verdict = 'suspicious')")
    )

    rep_ids = per_rep.map(&:first)
    reps = SalesUser.where(id: rep_ids).index_by(&:id)

    by_rep = per_rep.map do |sales_user_id, total, successful, with_corrections, gps_ok, gps_sus|
      rep = reps[sales_user_id]
      {
        sales_user_id: sales_user_id,
        rep_name: rep&.fullname.presence || rep&.email || 'Unknown',
        verifications_count: total,
        successful_count: successful,
        with_corrections_count: with_corrections,
        gps_verified_count: gps_ok,
        gps_suspicious_count: gps_sus
      }
    end
    by_rep.sort_by! { |r| -r[:verifications_count] }

    # Which fields get corrected most often — aggregate in Postgres instead of
    # plucking every jsonb blob into Ruby.
    corrections_by_field = scope.where.not(corrections: {})
      .joins('CROSS JOIN LATERAL jsonb_object_keys(corrections) AS field')
      .group('field')
      .count

    # One query for the three headline counts.
    total, successful, with_corrections = scope.pick(
      Arel.sql('COUNT(*)'),
      Arel.sql("COUNT(*) FILTER (WHERE outcome IN ('verified','corrected'))"),
      Arel.sql("COUNT(*) FILTER (WHERE corrections <> '{}'::jsonb)")
    )

    {
      total_verifications: total,
      successful_verifications: successful,
      verifications_with_corrections: with_corrections,
      outcomes: scope.group(:outcome).count,
      gps_verdicts: scope.group(:gps_verdict).count,
      corrections_by_field: corrections_by_field,
      by_rep: by_rep
    }
  end

  def truthy?(value)
    ActiveModel::Type::Boolean.new.cast(value)
  end

  # Nested under params[:follow_up]: {notes, follow_up_date, follow_up_type}.
  # Skipped silently when absent; a blank-notes issue/note is dropped rather
  # than failing the whole verification.
  def create_follow_up!(verification)
    fu = params[:follow_up]
    return if fu.blank?

    follow_up = @seller.seller_follow_ups.new(
      seller_verification: verification,
      sales_user: @current_sales_user,
      actor_name: @current_sales_user.fullname.presence || @current_sales_user.email,
      follow_up_type: fu[:follow_up_type].presence_in(SellerFollowUp.follow_up_types.keys) || 'note',
      notes: fu[:notes]&.strip&.presence,
      follow_up_date: (Date.parse(fu[:follow_up_date].to_s) rescue nil),
      occurred_at: verification.created_at
    )
    follow_up.save!
  rescue ActiveRecord::RecordInvalid
    # A follow-up that can't save (e.g. issue without notes) never fails the
    # verification itself — the visit record is more important.
    Rails.logger.warn "Seller verification #{verification.id} follow-up skipped: #{follow_up.errors.full_messages}"
  end

  # Shop-front photo evidence. Uploads to Cloudinary like other seller images;
  # landscape-oriented (cover-style). A failed upload never blocks the
  # verification itself.
  def upload_shop_photo(photo)
    return if photo.blank? || !photo.respond_to?(:tempfile) || photo.tempfile.blank?

    uploaded = Cloudinary::Uploader.upload(
      photo.tempfile.path,
      upload_preset: ENV['UPLOAD_PRESET'],
      folder: 'seller_verifications',
      transformation: [
        { width: 1600, crop: 'limit' },
        { quality: 'auto', fetch_format: 'auto' }
      ]
    )
    uploaded['secure_url']
  rescue => e
    Rails.logger.error "Seller verification photo upload failed: #{e.message}"
    nil
  end

  # The rep captured GPS while standing in the shop — treat it as ground truth
  # for the shop's pinned coordinates. Existing coordinates are only
  # overwritten when the GPS cross-check passed (verified), so a suspicious
  # reading can't clobber good data; a branch with no coordinates always gets
  # set. Runs after assess_gps! so the distance check still compares against
  # the previously recorded shop location.
  def sync_shop_coordinates!(verification)
    lat = verification.latitude&.to_f
    lng = verification.longitude&.to_f
    return unless lat && lng

    branch = main_branch

    if branch.nil?
      @seller.branches.create!(
        name: @seller.enterprise_name.presence || 'Main Branch',
        location: @seller.location.presence || verification.display_name.presence || "#{lat}, #{lng}",
        latitude: lat,
        longitude: lng,
        is_main_branch: true,
        location_precision: 'gps'
      )
      record_coordinate_correction(verification, nil, lat, lng)
    elsif branch.latitude.blank? || verification.gps_verdict == 'verified'
      return if branch.latitude&.to_f == lat && branch.longitude&.to_f == lng

      old = "#{branch.latitude&.to_f}, #{branch.longitude&.to_f}"
      updates = { latitude: lat, longitude: lng, location_precision: 'gps' }
      updates[:location] = @seller.location.presence || verification.display_name if branch.location.blank?
      branch.update!(updates)
      record_coordinate_correction(verification, old, lat, lng)
    end
  rescue => e
    Rails.logger.error "Seller verification #{verification.id} coordinate sync failed: #{e.message}"
  end

  # Main branch if set, otherwise the oldest branch — one query, memoized.
  def main_branch
    return @main_branch if defined?(@main_branch)

    @main_branch = @seller.branches.order(is_main_branch: :desc, id: :asc).first
  end

  def record_coordinate_correction(verification, old, lat, lng)
    verification.update!(
      corrections: verification.corrections.merge(
        'coordinates' => { 'old' => old, 'new' => "#{lat}, #{lng}" }
      )
    )
  end

  def build_verifications_csv(verifications)
    CSV.generate(headers: true) do |csv|
      csv << ['Date', 'Seller', 'Phone', 'Outcome', 'Verified By', 'Corrections', 'GPS Verdict', 'Distance to Shop (km)', 'Building', 'Room', 'Photo', 'Notes']
      verifications.each do |v|
        seller = v.seller
        rep = v.sales_user
        corrections = (v.corrections || {}).map do |field, diff|
          "#{SellerVerification.field_label(field)}: #{diff['old']} -> #{diff['new']}"
        end.join('; ')
        csv << [
          v.created_at&.strftime('%Y-%m-%d %H:%M'),
          seller&.enterprise_name.presence || seller&.fullname,
          seller&.phone_number,
          v.outcome,
          rep&.fullname.presence || rep&.email,
          corrections,
          v.gps_verdict,
          v.distance_to_shop_km&.to_f,
          v.building,
          v.room,
          v.photo_url,
          v.notes
        ]
      end
    end
  end

  def serialize_verification(verification, include_relations: false)
    data = {
      id: verification.id,
      seller_id: verification.seller_id,
      outcome: verification.outcome,
      location_confirmed: verification.location_confirmed,
      phone_confirmed: verification.phone_confirmed,
      business_name_confirmed: verification.business_name_confirmed,
      documents_confirmed: verification.documents_confirmed,
      corrections: verification.corrections,
      corrected_fields: verification.corrected_fields,
      notes: verification.notes,
      building: verification.building,
      room: verification.room,
      photo_url: verification.photo_url,
      latitude: verification.latitude&.to_f,
      longitude: verification.longitude&.to_f,
      display_name: verification.display_name,
      accuracy_m: verification.accuracy_m&.to_f,
      distance_to_shop_km: verification.distance_to_shop_km&.to_f,
      nearest_ping_distance_km: verification.nearest_ping_distance_km&.to_f,
      gps_verdict: verification.gps_verdict,
      created_at: verification.created_at&.iso8601
    }

    if include_relations
      seller = verification.seller
      rep = verification.sales_user
      data[:seller] = seller && {
        id: seller.id,
        enterprise_name: seller.enterprise_name,
        fullname: seller.fullname,
        location: seller.location,
        field_verified_at: seller.field_verified_at&.iso8601
      }
      data[:sales_user] = rep && {
        id: rep.id,
        fullname: rep.fullname,
        email: rep.email
      }
    end

    data
  end
end
