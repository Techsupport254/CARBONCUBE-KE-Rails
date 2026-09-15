# frozen_string_literal: true

module Sales
  # Brand Kenya directory — verified Kenyan manufacturers/producers that the
  # sales team is reaching out to. Tracks outreach status, scheduled
  # follow-ups ("come back on this day"), a full touchpoint timeline (calls,
  # visits, whatsapp, emails, meetings — repeatable), and platform
  # registration per brand.
  class BrandsController < ApplicationController
    before_action :authenticate_sales_user
    before_action :set_brand, only: %i[show update destroy create_activity]

    # GET /sales/brands
    # Params: search, category, status, part, follow_up (scheduled|overdue|today|upcoming),
    #         page, per_page
    def index
      page = (params[:page].presence || 1).to_i
      per_page = (params[:per_page].presence || 25).to_i.clamp(1, 100)

      brands = SalesBrand.includes(:sales_user, :activities).all
      brands = brands.search(params[:search]) if params[:search].present?
      brands = brands.where(category: params[:category]) if params[:category].present?
      brands = brands.where(status: params[:status]) if SalesBrand.statuses.key?(params[:status].to_s)
      brands = brands.where(part: params[:part]) if params[:part].present?

      case params[:follow_up]
      when 'scheduled' then brands = brands.with_follow_up
      when 'overdue'   then brands = brands.follow_up_overdue
      when 'today'     then brands = brands.follow_up_today
      when 'upcoming'  then brands = brands.follow_up_upcoming
      end

      brands = brands.order(:category, :name)
      total_count = brands.count
      brands = brands.offset((page - 1) * per_page).limit(per_page)

      render json: {
        data: brands.map { |b| serialize_brand(b) },
        meta: {
          current_page: page,
          per_page: per_page,
          total_count: total_count,
          total_pages: (total_count.to_f / per_page).ceil
        }
      }
    end

    # GET /sales/brands/:id
    # Brand detail + full activity timeline.
    def show
      render json: serialize_brand(@brand).merge(
        seller_registered: @brand.seller_id.present?,
        activities: @brand.activities.includes(:sales_user).map { |a| serialize_activity(a) }
      )
    end

    # POST /sales/brands
    # Quick-add a shop/prospect found in the field (not in the directory).
    # Captures GPS coordinates and can immediately log the first visit —
    # including the reason onboarding didn't succeed.
    def create
      # Dedup — a shop may already exist in the directory or have been added
      # by another rep. Match on normalized phone, then exact name.
      existing = find_duplicate_brand
      if existing
        log_optional_activity(existing)
        return render json: {
          success: true,
          existing: true,
          brand: serialize_brand(existing.reload)
        }
      end

      brand = SalesBrand.new(
        name: params[:name],
        source: 'field',
        sales_user: @current_sales_user,
        category: params[:category].presence,
        scope: params[:scope].presence,
        location: params[:location].presence,
        phone: params[:phone].presence,
        email: params[:email].presence,
        website: params[:website].presence,
        twitter: params[:twitter].presence,
        latitude: params[:latitude].presence,
        longitude: params[:longitude].presence,
        status: 'not_contacted'
      )

      unless brand.save
        return render json: { error: brand.errors.full_messages.join(', ') }, status: :unprocessable_entity
      end

      # Optionally log the visit/attempt that prompted the add
      if params[:activityType].present? || params[:notes].present? || params[:outcome].present?
        log_optional_activity(brand)
      end

      render json: { success: true, brand: serialize_brand(brand.reload) }, status: :created
    end

    # GET /sales/brands/follow_ups
    # Brands needing another touchpoint: scheduled follow-ups (bucketed
    # overdue/today/upcoming) plus hesitant prospects — shops visited where
    # onboarding didn't succeed and no date was agreed.
    def follow_ups
      scheduled = SalesBrand.includes(:sales_user, activities: :sales_user)
                            .with_follow_up
                            .order(follow_up_date: :asc)

      hesitant = SalesBrand.includes(:sales_user, activities: :sales_user)
                           .where(status: 'hesitant')
                           .order(last_contacted_at: :desc)

      render json: {
        data: scheduled.map { |b| serialize_brand(b).merge(follow_up_bucket: follow_up_bucket(b)) },
        hesitant: hesitant.map { |b| serialize_brand(b).merge(follow_up_bucket: 'hesitant') }
      }
    end

    # GET /sales/brands/stats
    # Status counts + follow-up due counts for dashboard KPI chips, plus the
    # list of categories for the filter dropdown.
    def stats
      render json: {
        total: SalesBrand.count,
        # Brands ever reached — derived from contact history (last_contacted_at
        # is rolled up from the activities timeline and never cleared), not the
        # mutable status field, so moving a brand to another status doesn't
        # shrink this number.
        reached: SalesBrand.where.not(last_contacted_at: nil).count,
        by_status: SalesBrand.group(:status).count,
        follow_ups_overdue: SalesBrand.follow_up_overdue.count,
        follow_ups_today: SalesBrand.follow_up_today.count,
        follow_ups_upcoming: SalesBrand.follow_up_upcoming.count,
        visits_total: SalesBrandActivity.where(activity_type: 'visit').count,
        calls_total: SalesBrandActivity.where(activity_type: 'call').count,
        field_added: SalesBrand.where(source: 'field').count,
        categories: SalesBrand.where.not(category: nil).distinct.order(:category).pluck(:category)
      }
    end

    # POST /sales/brands/:id/activities
    # Log a touchpoint: activityType (call|visit|whatsapp|email|meeting|note),
    # occurredAt, notes ("what they said"), outcome, followUpDate.
    def create_activity
      type = params[:activityType].to_s
      unless SalesBrandActivity.activity_types.key?(type)
        return render json: { error: "Invalid activity type '#{type}'" }, status: :unprocessable_entity
      end

      activity = @brand.record_activity!(
        type: type,
        user: @current_sales_user,
        occurred_at: parse_time(params[:occurredAt]),
        notes: params[:notes],
        outcome: params[:outcome],
        follow_up_date: params[:followUpDate].presence,
        latitude: params[:latitude].presence,
        longitude: params[:longitude].presence
      )

      render json: { success: true, activity: serialize_activity(activity), brand: serialize_brand(@brand.reload) }
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    # PATCH /sales/brands/:id
    # Update outreach fields: status, followUpDate, followUpNote, notes,
    # markContacted, sellerId (marks brand as registered), salesUserId
    # (assignment). Status changes and registration are auto-logged to the
    # activity timeline.
    def update
      update_attrs = {}

      update_attrs[:notes] = params[:notes] if params.key?(:notes)

      # Editable details — needed to fix field-added entries and enrich directory rows
      %i[name phone location category email website twitter scope].each do |field|
        update_attrs[field] = params[field] if params.key?(field)
      end
      update_attrs[:sales_user_id] = params[:salesUserId].presence if params.key?(:salesUserId)
      update_attrs[:last_contacted_at] = Time.current if params[:markContacted].to_s == 'true'

      if params[:sellerId].present?
        seller = Seller.find_by(id: params[:sellerId])
        return render json: { error: 'Seller not found' }, status: :not_found unless seller

        update_attrs[:seller_id] = seller.id
        update_attrs[:registered_at] = Time.current if @brand.registered_at.blank?
      end

      # Follow-up fields only apply directly when status isn't changing —
      # a status change goes through transition_to! which owns those fields.
      unless params.key?(:status)
        update_attrs[:follow_up_date] = params[:followUpDate].presence if params.key?(:followUpDate)
        update_attrs[:follow_up_note] = params[:followUpNote] if params.key?(:followUpNote)
      end

      if update_attrs.any? && !@brand.update(update_attrs)
        return render json: { error: @brand.errors.full_messages.join(', ') }, status: :unprocessable_entity
      end

      # Registration to a known seller → registered timeline entry + onboarded
      if update_attrs[:seller_id].present?
        @brand.activities.create!(
          activity_type: 'registered',
          sales_user: @current_sales_user,
          occurred_at: @brand.registered_at,
          notes: 'Registered on the platform as a seller'
        )
        params[:status] ||= 'onboarded'
      end

      if params.key?(:status)
        unless SalesBrand.statuses.key?(params[:status].to_s)
          return render json: { error: "Invalid status '#{params[:status]}'" }, status: :unprocessable_entity
        end

        begin
          @brand.transition_to!(
            params[:status],
            actor: @current_sales_user,
            follow_up_date: params[:followUpDate],
            follow_up_note: params[:followUpNote]
          )
        rescue SalesBrand::TransitionError => e
          return render json: { error: e.message }, status: :unprocessable_entity
        end
      elsif params.key?(:followUpDate) && params[:followUpDate].blank? && @brand.follow_up?
        # Clearing the date should also clear stale "follow_up" status
        @brand.transition_to!('contacted', actor: @current_sales_user)
      end

      render json: { success: true, brand: serialize_brand(@brand.reload) }
    end

    # DELETE /sales/brands/:id
    # Only field-added prospects can be removed — the verified directory is protected.
    def destroy
      unless @brand.field?
        return render json: { error: 'Directory brands cannot be deleted' }, status: :forbidden
      end

      @brand.destroy
      render json: { success: true }
    end

    private

    def set_brand
      @brand = SalesBrand.find_by(id: params[:id])
      render json: { error: 'Brand not found' }, status: :not_found unless @brand
    end

    def follow_up_bucket(brand)
      return nil if brand.follow_up_date.blank?

      if brand.follow_up_date < Date.current
        'overdue'
      elsif brand.follow_up_date == Date.current
        'today'
      else
        'upcoming'
      end
    end

    # Match on phone suffix (normalized) or exact name to avoid duplicate
    # prospects — a shop might already be in the directory or added by a
    # colleague on an earlier route.
    def find_duplicate_brand
      if params[:phone].present?
        digits = params[:phone].to_s.gsub(/\D/, '')
        if digits.length >= 9
          suffix = digits[-9..]
          match = SalesBrand.where('phone LIKE ?', "%#{suffix}").first
          return match if match
        end
      end

      return nil if params[:name].blank?

      SalesBrand.where('LOWER(name) = ?', params[:name].to_s.strip.downcase).first
    end

    def log_optional_activity(brand)
      type = params[:activityType].presence || 'visit'
      type = 'visit' unless SalesBrandActivity.activity_types.key?(type)

      brand.record_activity!(
        type: type,
        user: @current_sales_user,
        occurred_at: parse_time(params[:occurredAt]),
        notes: params[:notes],
        outcome: params[:outcome],
        follow_up_date: params[:followUpDate].presence,
        latitude: params[:latitude].presence,
        longitude: params[:longitude].presence
      )
    end

    def parse_time(value)
      return nil if value.blank?

      Time.zone.parse(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def serialize_activity(activity)
      {
        id: activity.id,
        activity_type: activity.activity_type,
        occurred_at: activity.occurred_at,
        notes: activity.notes,
        outcome: activity.outcome,
        follow_up_date: activity.follow_up_date,
        latitude: activity.latitude,
        longitude: activity.longitude,
        agent_name: activity.sales_user&.fullname,
        created_at: activity.created_at
      }
    end

    def serialize_brand(brand)
      activities = brand.activities.loaded? ? brand.activities : brand.activities.to_a
      last_contact = activities.find { |a| SalesBrandActivity::CONTACT_TYPES.include?(a.activity_type) }
      last_actor = activities.find { |a| a.sales_user_id.present? }
      {
        id: brand.id,
        name: brand.name,
        part: brand.part,
        category: brand.category,
        subcategories: brand.subcategories || [],
        scope: brand.scope,
        location: brand.location,
        phone: brand.phone,
        email: brand.email,
        website: brand.website,
        twitter: brand.twitter,
        status: brand.status,
        follow_up_date: brand.follow_up_date,
        follow_up_note: brand.follow_up_note,
        notes: brand.notes,
        last_contacted_at: brand.last_contacted_at,
        sales_user_id: brand.sales_user_id,
        agent_name: brand.sales_user&.fullname || last_actor&.sales_user&.fullname,
        seller_id: brand.seller_id,
        registered_at: brand.registered_at,
        source: brand.source,
        latitude: brand.latitude,
        longitude: brand.longitude,
        last_activity_notes: last_contact&.notes,
        last_activity_outcome: last_contact&.outcome,
        visits_count: activities.count { |a| a.activity_type == 'visit' },
        calls_count: activities.count { |a| a.activity_type == 'call' },
        activities_count: activities.size,
        created_at: brand.created_at,
        updated_at: brand.updated_at
      }
    end

    def authenticate_sales_user
      @current_sales_user = SalesAuthorizeApiRequest.new(request.headers).result
      render json: { error: 'Not Authorized' }, status: :unauthorized unless @current_sales_user
    end
  end
end
