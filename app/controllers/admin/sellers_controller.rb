class Admin::SellersController < ApplicationController
  before_action :authenticate_admin_or_sales, only: [:index, :show, :ads, :reviews, :analytics, :verify_document, :send_reminder, :updates]
  before_action :authenticate_admin, except: [:index, :show, :ads, :reviews, :analytics, :verify_document, :send_reminder, :updates]
  before_action :set_seller, only: [:block, :unblock, :flag, :unflag, :show, :update, :destroy, :analytics, :orders, :ads, :reviews, :verify_document, :send_reminder, :updates]

  def index
    cache_key = "admin_sellers/index_v3/#{Digest::SHA1.hexdigest(params.to_unsafe_h.slice('query', 'status', 'sort_by', 'sort_order', 'page', 'per_page').compact.to_json)}"
    sellers_response = Rails.cache.fetch(cache_key, expires_in: 5.minutes, race_condition_ttl: 10.seconds) do
      sellers_query = Seller.unscoped
      
      if params[:query].present?
        search_term = params[:query].strip
        sellers_query = sellers_query.where(
          "fullname ILIKE :search OR 
           phone_number ILIKE :search OR 
           email ILIKE :search OR 
           enterprise_name ILIKE :search OR 
           location ILIKE :search OR 
           sellers.id::text = :exact_search",
          search: "%#{search_term}%",
          exact_search: search_term
        )
      end
      
      if params[:status].present?
        case params[:status]
        when 'active'
          sellers_query = sellers_query.where(blocked: false, deleted: false, flagged: false)
        when 'blocked'
          sellers_query = sellers_query.where(blocked: true)
        when 'deleted'
          sellers_query = sellers_query.where(deleted: true)
        when 'flagged'
          sellers_query = sellers_query.where(flagged: true)
        when 'call_queue'
          sellers_query = sellers_query.where(id: CallQueue.pending.select(:seller_id))
        when 'all'
        end
      end
      
      sort_by = params[:sort_by] || 'created_at'
      sort_order = params[:sort_order] || 'desc'
      
      allowed_sort_fields = %w[id fullname email enterprise_name location created_at updated_at last_active_at total_ads]
      allowed_sort_orders = %w[asc desc]

      sort_by = 'created_at' unless allowed_sort_fields.include?(sort_by)
      sort_order = 'asc' unless allowed_sort_orders.include?(sort_order)

      sort_by = 'last_active_at' if sort_by == 'last_activity'
      filtered_query = sellers_query
      sellers_query = filtered_query
        .left_outer_joins(:ads)
        .where("ads.deleted = ? OR ads.id IS NULL", false)
        .group('sellers.id')
        .select('sellers.*, COUNT(ads.id) AS total_ads_count')
        .includes(:carbon_code)
      sellers_query = if sort_by == 'total_ads'
        sellers_query.order("total_ads_count #{sort_order}")
      else
        sellers_query.order("sellers.#{sort_by} #{sort_order}")
      end

      page = params[:page]&.to_i || 1
      per_page = params[:per_page]&.to_i || 20

      page = 1 if page < 1
      per_page = [per_page, 100].min # Max 100 per page
      per_page = 20 if per_page < 1

      total_count = filtered_query.count
      offset = (page - 1) * per_page
      
      @sellers = sellers_query.limit(per_page).offset(offset)

      in_call_queue_entries = CallQueue.pending.where(seller_id: @sellers.map(&:id)).select(:seller_id, :reasons)
      in_call_queue_ids = in_call_queue_entries.map(&:seller_id).to_set
      in_call_queue_reasons = in_call_queue_entries.index_by(&:seller_id).transform_values { |q| q.reasons || [] }

      carbon_code_cutoff = Time.zone.parse('2026-02-01').beginning_of_day

      @sellers_data = @sellers.map do |seller|
        row = seller.as_json(only: [:id, :fullname, :phone_number, :email, :enterprise_name, :location, :blocked, :deleted, :flagged, :created_at, :updated_at, :last_active_at, :profile_picture, :provider, :carbon_code_id], include: { carbon_code: { only: [:id, :code, :label] } })
        row['total_ads'] = seller[:total_ads_count] || 0
        row['in_call_queue'] = in_call_queue_ids.include?(seller.id)
        row['call_queue_reasons'] = in_call_queue_reasons[seller.id] || []
        row['call_queue_reasons_display'] = (in_call_queue_reasons[seller.id] || []).map { |r| CallQueue::QUEUE_TYPES[r] || r.humanize }
        row['onboarding_type'] = if seller.carbon_code_id.present?
          'added_by_sales'
        elsif seller.created_at && seller.created_at >= carbon_code_cutoff
          'self_onboarded'
        else
          'legacy'
        end
        row
      end
      
      total_pages = (total_count.to_f / per_page).ceil
      has_next_page = page < total_pages
      has_prev_page = page > 1
      
      {
        sellers: @sellers_data,
        pagination: {
          current_page: page,
          per_page: per_page,
          total_count: total_count,
          total_pages: total_pages,
          has_next_page: has_next_page,
          has_prev_page: has_prev_page,
          next_page: has_next_page ? page + 1 : nil,
          prev_page: has_prev_page ? page - 1 : nil
        }
      }
    end

    render json: sellers_response
  end

  def show
    cache_key = "admin_seller_show_v3/#{@seller.id}_#{@seller.updated_at.to_i}"
    seller_data = Rails.cache.fetch(cache_key, expires_in: 5.minutes, race_condition_ttl: 10.seconds) do
      data = @seller.as_json(
        only: [
          :id, :fullname, :username, :description, :phone_number, :email, 
          :enterprise_name, :location, :blocked, :profile_picture, :zipcode, 
          :city, :gender, :business_registration_number, :document_url,
          :document_verified, :document_expiry_date, :created_at, :updated_at,
          :last_active_at, :deleted, :provider, :uid, :ads_count, :carbon_code_id
        ],
        methods: [:category_names],
        include: {
          county: { only: [:id, :name, :capital, :county_code] },
          sub_county: { only: [:id, :name] },
          age_group: { only: [:id, :name] },
          document_type: { only: [:id, :name] },
          tier: { only: [:id, :name] },
          carbon_code: { only: [:id, :code, :label] }
        }
      )
      analytics_data = fetch_analytics(@seller)
      data.merge(analytics: analytics_data)
    end
    render json: seller_data
  end

  def create
    @seller = Seller.new(seller_params)
    if @seller.save
      assign_default_tier_for_seller(@seller) if @seller.seller_tier.blank?
      create_default_branch_for_seller(@seller) if @seller.branches.empty?
      render json: @seller.as_json(only: [:id, :fullname, :enterprise_name, :location, :blocked]), status: :created
    else
      render json: @seller.errors, status: :unprocessable_entity
    end
  end

  def update
    if @seller.update(seller_params)
      render json: @seller.as_json(only: [:id, :fullname, :phone_number, :email, :enterprise_name, :location, :blocked])
    else
      render json: @seller.errors, status: :unprocessable_entity
    end
  end

  def verify_document
    seller = Seller.find(params[:id])
    seller.update(document_verified: true)
    render json: { message: 'Seller document verified.' }, status: :ok
  end

  def destroy
    @seller.destroy
    head :no_content
  end

  def reviews
    cache_key = "seller_reviews_v3_#{@seller.id}_#{@seller.updated_at.to_i}"
    reviews_data = Rails.cache.fetch(cache_key, expires_in: 10.minutes) do
      @seller.reviews_received.includes(:ad, :buyer)
             .where(ads: { id: @seller.ads.select(:id) })
             .order(created_at: :desc)
             .map do |r|
               ad = r.ad
               buyer = r.buyer
               {
                 id: r.id,
                 rating: r.rating,
                 review: r.review,
                 created_at: r.created_at,
                 buyer_name: buyer&.fullname || 'Verified Customer',
                 ad_id: ad&.id,
                 ad_title: ad&.title,
                 ad_price: ad&.price,
                 ad_image: ad&.first_media_url
               }
             end
    end
    render json: reviews_data
  end
  

  def ads
    cache_key = "seller_ads_v2_#{@seller.id}_#{@seller.updated_at.to_i}"
    ads_data = Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
      @seller.ads.where(deleted: false).order(created_at: :desc).as_json(
        methods: [:first_media_url, :media_urls, :media],
        only: [:id, :title, :price, :created_at]
      )
    end
    render json: ads_data
  end

  def updates
    events = []
    seller = @seller

    # Messages from the seller's conversations
    Message.where(conversation_id: seller.conversations.select(:id))
           .includes(:sender, :ad)
           .order(created_at: :desc)
           .limit(100)
           .each do |msg|
      sender_name = msg.sender&.try(:fullname) || msg.sender&.try(:enterprise_name) || msg.sender_type
      events << {
        id: "message-#{msg.id}",
        type: 'message',
        title: 'Message',
        description: msg.content.to_s.truncate(180),
        timestamp: msg.created_at.iso8601,
        meta: {
          sender_type: msg.sender_type,
          sender_name: sender_name,
          ad_title: msg.ad&.title,
          status: msg.status
        }
      }
    end

    # Notifications sent to the seller
    Notification.where(recipient: seller)
                .order(created_at: :desc)
                .limit(50)
                .each do |n|
      events << {
        id: "notification-#{n.id}",
        type: 'notification',
        title: n.title || 'Notification',
        description: n.body.to_s.truncate(200),
        timestamp: n.created_at.iso8601,
        meta: { read: n.read_at.present? }
      }
    end

    # Seller ads and status changes
    seller.ads.order(created_at: :desc).limit(50).each do |ad|
      events << {
        id: "ad-#{ad.id}-created",
        type: 'ad',
        title: 'Ad posted',
        description: ad.title,
        timestamp: ad.created_at.iso8601,
        meta: { ad_id: ad.id, price: ad.price }
      }

      if ad.updated_at > ad.created_at + 1.minute
        events << {
          id: "ad-#{ad.id}-updated",
          type: 'ad',
          title: 'Ad updated',
          description: ad.title,
          timestamp: ad.updated_at.iso8601,
          meta: { ad_id: ad.id }
        }
      end

      if ad.deleted
        events << {
          id: "ad-#{ad.id}-deleted",
          type: 'ad',
          title: 'Ad deleted',
          description: ad.title,
          timestamp: ad.updated_at.iso8601,
          meta: { ad_id: ad.id }
        }
      end

      if ad.flagged
        events << {
          id: "ad-#{ad.id}-flagged",
          type: 'ad',
          title: 'Ad flagged',
          description: ad.title,
          timestamp: ad.updated_at.iso8601,
          meta: { ad_id: ad.id }
        }
      end
    end

    # Reviews received on the seller's ads
    seller.reviews_received.includes(:ad, :buyer, :seller)
          .order(created_at: :desc)
          .limit(50)
          .each do |r|
      reviewer = r.buyer&.fullname || r.seller&.fullname || 'Verified Customer'
      events << {
        id: "review-#{r.id}",
        type: 'review',
        title: 'Review received',
        description: "#{reviewer} rated #{r.rating}/5 — #{r.review.to_s.truncate(140)}",
        timestamp: r.created_at.iso8601,
        meta: { ad_id: r.ad_id, ad_title: r.ad&.title, rating: r.rating }
      }
    end

    # Document uploads and updates
    seller.seller_documents.includes(:document_type)
          .order(created_at: :desc)
          .each do |doc|
      doc_name = doc.document_type&.name || 'Document'
      events << {
        id: "document-#{doc.id}-created",
        type: 'document',
        title: 'Document uploaded',
        description: doc_name,
        timestamp: doc.created_at.iso8601,
        meta: { verified: doc.document_verified, expiry: doc.document_expiry_date }
      }

      if doc.updated_at > doc.created_at + 1.minute
        events << {
          id: "document-#{doc.id}-updated",
          type: 'document',
          title: 'Document updated',
          description: doc_name,
          timestamp: doc.updated_at.iso8601,
          meta: { verified: doc.document_verified, expiry: doc.document_expiry_date }
        }
      end
    end

    # WhatsApp reminders
    seller.whatsapp_message_logs.where(sent_successfully: true)
          .order(sent_at: :desc)
          .each do |log|
      events << {
        id: "whatsapp-#{log.id}",
        type: 'whatsapp',
        title: 'WhatsApp reminder sent',
        description: log.template_name,
        timestamp: (log.sent_at || log.created_at).iso8601,
        meta: { phone_number: log.phone_number }
      }
    end

    # Emails sent
    seller.email_communication_logs.where(sent_successfully: true)
          .order(sent_at: :desc)
          .each do |log|
      events << {
        id: "email-#{log.id}",
        type: 'email',
        title: 'Email sent',
        description: log.email_type,
        timestamp: (log.sent_at || log.created_at).iso8601,
        meta: {}
      }
    end

    # Calls with the seller
    CallRecord.where(customer: seller)
              .order(created_at: :desc)
              .limit(50)
              .each do |call|
      duration = call.duration_seconds ? "#{call.duration_seconds}s" : 'no duration'
      events << {
        id: "call-#{call.id}",
        type: 'call',
        title: "#{call.call_type&.humanize || 'Call'} call — #{call.status&.humanize || 'unknown'}",
        description: "#{duration} · #{call.call_reason || call.issue_category || call.call_source&.humanize || ''}".strip,
        timestamp: (call.started_at || call.created_at).iso8601,
        meta: { duration_seconds: call.duration_seconds, status: call.status }
      }
    end

    # Account lifecycle
    events << {
      id: 'account-created',
      type: 'account',
      title: 'Account created',
      description: '',
      timestamp: seller.created_at.iso8601
    }

    if seller.blocked
      events << {
        id: 'account-blocked',
        type: 'account',
        title: 'Account blocked',
        description: '',
        timestamp: seller.updated_at.iso8601
      }
    end

    if seller.flagged
      events << {
        id: 'account-flagged',
        type: 'account',
        title: 'Account flagged',
        description: '',
        timestamp: seller.updated_at.iso8601
      }
    end

    if seller.deleted
      events << {
        id: 'account-deleted',
        type: 'account',
        title: 'Account deleted',
        description: '',
        timestamp: seller.updated_at.iso8601
      }
    end

    events.sort_by! { |e| e[:timestamp] }.reverse!
    events = events.first(200)

    render json: { seller_id: seller.id, events: events }
  end

  def block
    if @seller
      mean_rating = @seller.reviews_received.average(:rating).to_f

      if mean_rating < 3.0
        if @seller.update(blocked: true)
          render json: @seller.as_json(only: [:id, :fullname, :enterprise_name, :location, :blocked]), status: :ok
        else
          render json: @seller.errors, status: :unprocessable_entity
        end
      else
        render json: { error: 'Seller cannot be blocked because their mean rating is above 3.0' }, status: :unprocessable_entity
      end
    else
      render json: { error: 'Seller not found' }, status: :not_found
    end
  end

  def unblock
    if @seller
      if @seller.update(blocked: false)
        render json: @seller.as_json(only: [:id, :fullname, :enterprise_name, :location, :blocked]), status: :ok
      else
        render json: @seller.errors, status: :unprocessable_entity
      end
    else
      render json: { error: 'Seller not found' }, status: :not_found
    end
  end

  def flag
    if @seller
      flag_notes = params[:notes] || params[:flag_notes]
      if @seller.update(flagged: true, flag_notes: flag_notes)
        SellerMailer.account_flagged(@seller, flag_notes).deliver_now
        render json: @seller.as_json(only: [:id, :fullname, :enterprise_name, :location, :flagged, :flag_notes]), status: :ok
      else
        render json: @seller.errors, status: :unprocessable_entity
      end
    else
      render json: { error: 'Seller not found' }, status: :not_found
    end
  end

  def unflag
    if @seller
      if @seller.update(flagged: false)
        render json: @seller.as_json(only: [:id, :fullname, :enterprise_name, :location, :flagged]), status: :ok
      else
        render json: @seller.errors, status: :unprocessable_entity
      end
    else
      render json: { error: 'Seller not found' }, status: :not_found
    end
  end

  def bulk_actions
    action = params[:action_type]
    seller_ids = params[:seller_ids] || []
    
    if seller_ids.empty?
      render json: { error: 'No sellers selected' }, status: :bad_request
      return
    end

    sellers = Seller.where(id: seller_ids)
    
    case action
    when 'block'
      sellers.update_all(blocked: true)
      render json: { message: "#{sellers.count} sellers blocked successfully" }
    when 'unblock'
      sellers.update_all(blocked: false)
      render json: { message: "#{sellers.count} sellers unblocked successfully" }
    when 'flag'
      sellers.update_all(flagged: true)
      render json: { message: "#{sellers.count} sellers flagged successfully" }
    when 'unflag'
      sellers.update_all(flagged: false)
      render json: { message: "#{sellers.count} sellers unflagged successfully" }
    when 'delete'
      sellers.update_all(deleted: true)
      render json: { message: "#{sellers.count} sellers deleted successfully" }
    else
      render json: { error: 'Invalid action type' }, status: :bad_request
    end
  end

  def analytics
    analytics_data = fetch_analytics(@seller)
    render json: analytics_data
  end

  def orders
    @orders = @seller.orders.includes(:buyer, :order_items).order(created_at: :desc)
    render json: @orders.as_json(include: { buyer: { only: [:fullname] }, order_items: { only: [:id, :quantity, :price] } })
  end

  def assign_carbon_code
    seller = Seller.find(params[:id])
    carbon_code = CarbonCode.find_by(code: params[:carbon_code].to_s.strip.upcase)
    
    unless carbon_code
      render json: { error: 'Carbon code not found' }, status: :not_found
      return
    end

    unless carbon_code.valid_for_use?
      render json: { error: 'Carbon code is expired or max uses reached' }, status: :unprocessable_entity
      return
    end

    if seller.update(carbon_code_id: carbon_code.id)
      carbon_code.increment!(:times_used)
      render json: { message: 'Carbon code assigned successfully', carbon_code: carbon_code.code, label: carbon_code.label }, status: :ok
    else
      render json: { error: 'Failed to assign carbon code', details: seller.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def send_reminder
    unless @seller
      render json: { error: 'Seller not found' }, status: :not_found
      return
    end

    reminder_type = params[:reminder_type] || 'general'
    channel = params[:channel] || 'whatsapp'
    custom_message = params[:message]
    custom_subject = params[:subject]
    target_phone = params[:phone]
    target_email = params[:email]

    if Rails.env.development?
      target_phone = '0716404137'
      target_email = 'kiruivictor097@gmail.com'
    end

    SendComplianceReminderSequenceJob.perform_later(
      @seller.id,
      reminder_type,
      target_phone: target_phone,
      target_email: target_email,
      count: 0
    )

    render json: {
      success: true,
      message: "Compliance reminder sequence queued for #{@seller.enterprise_name || @seller.fullname}"
    }, status: :ok
  end

  private

  def assign_default_tier_for_seller(seller)
    free_tier = Tier.find_by(name: 'Free')
    return unless free_tier

    seller.create_seller_tier!(
      tier_id: free_tier.id,
      payment_frequency: 'monthly',
      expires_at: 100.years.from_now
    )
  end

  def create_default_branch_for_seller(seller)
    return unless seller.location.present?
    return if seller.branches.exists?

    seller.branches.create!(
      name: seller.enterprise_name || seller.fullname || "Main Branch",
      location: seller.location,
      is_main_branch: true,
      county_id: seller.county_id,
      sub_county_id: seller.sub_county_id
    )
  end

  def set_seller
    @seller = Seller.includes(:county, :sub_county, :age_group, :document_type, :tier, :carbon_code, :categories).find(params[:id])
  end

  def seller_params
    params.require(:seller).permit(:fullname, :phone_number, :email, :enterprise_name, :location, :password, :business_registration_number, :facebook_url, :instagram_url, :whatsapp_url, :tiktok_url, :twitter_url, :linkedin_url, :website, category_ids: [])
  end

  def authenticate_admin_or_sales
    begin
      @current_user = AdminAuthorizeApiRequest.new(request.headers).result
    rescue ExceptionHandler::InvalidToken, ExceptionHandler::MissingToken
      @current_user = SalesAuthorizeApiRequest.new(request.headers).result
    end
    unless @current_user && (@current_user.is_a?(Admin) || @current_user.is_a?(SalesUser))
      render json: { error: 'Not Authorized' }, status: :unauthorized
      return
    end
  end

  def authenticate_admin
    @current_user = AdminAuthorizeApiRequest.new(request.headers).result
    unless @current_user && @current_user.is_a?(Admin)
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end


  def most_clicked_ad(seller)
    ad_ids = seller.ads.where(deleted: false).pluck(:id)
    return nil if ad_ids.empty?

    most_clicked = ClickEvent.where(ad_id: ad_ids)
                             .group(:ad_id)
                             .order(Arel.sql('COUNT(id) DESC'))
                             .limit(1)
                             .count(:id)
                             .first
  
    if most_clicked
      ad = Ad.includes(:category).find_by(id: most_clicked[0])
      if ad
        {
          ad_id: ad.id,
          title: ad.title,
          total_clicks: most_clicked[1],
          category: ad.category&.name || "General",
          first_media_url: ad.first_media_url,
          media_urls: ad.media_urls,
          media: ad.media
        }
      end
    end
  end
  
  def fetch_analytics(seller)
    cache_key = "seller_analytics_v4/#{seller.id}_#{seller.updated_at.to_i}"
    Rails.cache.fetch(cache_key, expires_in: 10.minutes, race_condition_ttl: 15.seconds) do
      seller_ads = seller.ads.where(deleted: false)
      ad_ids = seller_ads.pluck(:id)
      
      click_events = if ad_ids.present?
        ClickEvent
          .excluding_internal_users
          .where(ad_id: ad_ids)
          .joins(:ad)
          .where(ads: { deleted: false })
          .left_joins(:buyer)
          .where("buyers.id IS NULL OR buyers.deleted = ?", false)
          .where(
            "NOT (
              (click_events.metadata->>'user_role' = 'seller' OR click_events.metadata->>'user_role' = 'Seller')
              AND click_events.metadata->>'user_id' IS NOT NULL
              AND ads.seller_id IS NOT NULL
              AND CAST(click_events.metadata->>'user_id' AS TEXT) = CAST(ads.seller_id AS TEXT)
            )"
          )
      else
        ClickEvent.none
      end
      
      contact_interaction_events = if ad_ids.present?
        click_events
          .where(event_type: 'Reveal-Seller-Details')
          .where("click_events.metadata->>'action' = ?", 'seller_contact_interaction')
          .group(Arel.sql("click_events.metadata->>'action_type'"))
          .count
      else
        {}
      end
      
      click_event_counts = if ad_ids.present?
        click_events.group(:event_type).count
      else
        {}
      end
    
      total_clicks = click_event_counts["Ad-Click"] || 0
      total_profile_views = click_event_counts["Reveal-Seller-Details"] || 0
      reveal_seller_details_clicks = click_event_counts["Reveal-Seller-Details"] || 0
      
      copy_clicks = (contact_interaction_events['copy_phone'] || 0) + (contact_interaction_events['copy_email'] || 0)
      call_clicks = contact_interaction_events['call_phone'] || 0
      whatsapp_clicks = contact_interaction_events['whatsapp'] || 0
      location_clicks = contact_interaction_events['view_location'] || 0
      total_contact_interactions = copy_clicks + call_clicks + whatsapp_clicks + location_clicks

      # Global rankings computed and cached
      ad_performance_rankings = Rails.cache.fetch("global_seller_ad_performance_rankings_v2", expires_in: 30.minutes) do
        Seller.joins(ads: :click_events)
              .where(sellers: { deleted: false, blocked: false })
              .group("sellers.id")
              .order(Arel.sql("COUNT(click_events.id) DESC"))
              .count("click_events.id")
              .keys
      end
      ad_performance_rank = ad_performance_rankings.index(seller.id)&.next
      total_ranked_sellers = ad_performance_rankings.size
      
      last_activity = seller_ads.maximum(:updated_at)
      total_ads_updated = seller_ads.where.not("ads.updated_at = ads.created_at").count
      total_ads_count = seller_ads.count
      ad_approval_rate = total_ads_count > 0 ? (seller_ads.where(approved: true).count.to_f / total_ads_count * 100).round(2) : 100.0 rescue 100.0
    
      top_category = if ad_ids.present?
        Ad.where(id: ad_ids).joins(:category).group("categories.name").order(Arel.sql("COUNT(ads.id) DESC")).limit(1).pluck("categories.name").first || "General"
      else
        seller.categories.first&.name || "General"
      end

      seller_category = seller.category || seller.categories.first
      seller_category_id = seller_category&.id

      seller_category_rank = nil
      total_category_sellers = 0
      if seller_category_id.present?
        cat_rankings = Rails.cache.fetch("seller_category_rankings_#{seller_category_id}", expires_in: 30.minutes) do
          Seller.joins(:ads)
                .where(ads: { category_id: seller_category_id, deleted: false })
                .group("sellers.id")
                .order(Arel.sql("COUNT(ads.id) DESC"))
                .count
                .keys
        end
        seller_category_rank = cat_rankings.index(seller.id)&.next
        total_category_sellers = cat_rankings.size
      end
    
      wishlist_count = click_event_counts["Add-to-Wish-List"] || 0
      wishlist_to_click_ratio = total_clicks > 0 ? (wishlist_count.to_f / total_clicks * 100).round(2) : 0.0
      wishlist_to_contact_ratio = reveal_seller_details_clicks > 0 ? (wishlist_count.to_f / reveal_seller_details_clicks * 100).round(2) : 0.0
      
      most_wishlisted_ad_data = if ad_ids.present?
        most_wishlisted = WishList.where(ad_id: ad_ids)
                                  .group(:ad_id)
                                  .order(Arel.sql('COUNT(id) DESC'))
                                  .limit(1)
                                  .count(:id)
                                  .first
        if most_wishlisted
          ad = Ad.includes(:category).find_by(id: most_wishlisted[0])
          ad&.as_json(methods: [:first_media_url, :media_urls, :media], only: [:id, :title])
        end
      end
      
      # Single-query review and rating aggregation
      rating_stats = if ad_ids.present?
        seller.reviews_received.joins(:ad).where(ads: { id: ad_ids }).group(:rating).count
      else
        {}
      end
      total_reviews_count = rating_stats.values.sum
      mean_rating = total_reviews_count > 0 ? (rating_stats.sum { |rating, count| rating * count }.to_f / total_reviews_count).round(2) : 0.0
    
      {
        total_ads: total_ads_count,
        total_ads_wishlisted: ad_ids.present? ? WishList.where(ad_id: ad_ids).count : 0,
        mean_rating: mean_rating,
        total_reviews: total_reviews_count,
        rating_pie_chart: (1..5).map do |rating|
          {
            rating: rating,
            count: rating_stats[rating] || 0
          }
        end,
        reviews: ad_ids.present? ? seller.reviews_received.includes(:ad, :buyer)
                        .where(ads: { id: ad_ids })
                        .order(created_at: :desc)
                        .limit(20)
                        .map do |r|
                          ad = r.ad
                          buyer = r.buyer
                          {
                            id: r.id,
                            rating: r.rating,
                            review: r.review,
                            created_at: r.created_at,
                            buyer_name: buyer&.fullname || 'Verified Customer',
                            ad_id: ad&.id,
                            ad_title: ad&.title,
                            ad_price: ad&.price,
                            ad_image: ad&.first_media_url
                          }
                        end : [],
    
        ad_clicks: total_clicks,
        add_to_wish_list: wishlist_count,
        reveal_seller_details: reveal_seller_details_clicks,
        total_click_events: click_events.count,
        
        copy_clicks: copy_clicks,
        call_clicks: call_clicks,
        whatsapp_clicks: whatsapp_clicks,
        location_clicks: location_clicks,
        total_contact_interactions: total_contact_interactions,
    
        total_profile_views: total_profile_views,
        ad_performance_rank: ad_performance_rank,
        total_ranked_sellers: total_ranked_sellers,
        category_rank: seller_category_rank,
        total_category_sellers: total_category_sellers,
    
        last_activity: last_activity,
        total_ads_updated: total_ads_updated,
        ad_approval_rate: ad_approval_rate,
    
        seller_category: seller_category&.name || top_category,
        top_performing_category: top_category,
    
        wishlist_to_click_ratio: wishlist_to_click_ratio,
        wishlist_to_contact_ratio: wishlist_to_contact_ratio,
        most_wishlisted_ad: most_wishlisted_ad_data,
        most_clicked_ad: most_clicked_ad(seller),
    
        last_ad_posted_at: seller_ads.maximum(:created_at),
        account_age_days: (Time.current.to_date - seller.created_at.to_date).to_i,
        
        composite_score: (
          (total_clicks * 0.20) +
          (reveal_seller_details_clicks * 0.35) +
          (total_contact_interactions * 0.15) +
          (wishlist_count * 0.10) +
          (total_reviews_count * 0.10) +
          (mean_rating * 10 * 0.10)
        ).round(2)
      }
    end
  end
end
