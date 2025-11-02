class Sales::ClickEventsController < ApplicationController
  before_action :authenticate_sales_user

  def analytics
    begin
      # Apply base filter: exclude internal users from all analytics
      base_query = ClickEvent.excluding_internal_users
      
      # Apply filters from params
      filtered_query = base_query
      
      # Filter by event type
      if params[:event_type].present?
        filtered_query = filtered_query.where(event_type: params[:event_type])
      end
      
      # Filter by user status (guest vs authenticated)
      if params[:user_status] == 'guest'
        filtered_query = filtered_query.where(buyer_id: nil)
      elsif params[:user_status] == 'authenticated'
        filtered_query = filtered_query.where.not(buyer_id: nil)
      end
      
      # Filter by date range
      if params[:start_date].present?
        start_date = Time.parse(params[:start_date]) rescue nil
        filtered_query = filtered_query.where('created_at >= ?', start_date) if start_date
      end
      
      if params[:end_date].present?
        end_date = Time.parse(params[:end_date]) rescue nil
        filtered_query = filtered_query.where('created_at <= ?', end_date) if end_date
      end
      
      # Get all click events with timestamps (excluding internal users)
      all_click_events = filtered_query.order(created_at: :desc)
      all_reveal_events = filtered_query.where(event_type: 'Reveal-Seller-Details').order(created_at: :desc)
      all_ad_clicks = filtered_query.where(event_type: 'Ad-Click').order(created_at: :desc)
      
      # For counts, always use base query (excluding internal users) unless filtered
      base_all_click_events = base_query.order(created_at: :desc)
      base_all_reveal_events = base_query.where(event_type: 'Reveal-Seller-Details').order(created_at: :desc)
      base_all_ad_clicks = base_query.where(event_type: 'Ad-Click').order(created_at: :desc)

      # Get timestamps for frontend filtering (from base query excluding internal users)
      click_events_timestamps = base_all_click_events.pluck(:created_at).map { |ts| ts&.iso8601 }
      reveal_events_timestamps = base_all_reveal_events.pluck(:created_at).map { |ts| ts&.iso8601 }
      ad_clicks_timestamps = base_all_ad_clicks.pluck(:created_at).map { |ts| ts&.iso8601 }

      # Get guest vs authenticated breakdown (from base query excluding internal users)
      guest_reveals = base_all_reveal_events.where(buyer_id: nil).count
      authenticated_reveals = base_all_reveal_events.where.not(buyer_id: nil).count
      
      guest_reveal_timestamps = base_query
        .where(event_type: 'Reveal-Seller-Details', buyer_id: nil)
        .pluck(:created_at)
        .map { |ts| ts&.iso8601 }
      
      authenticated_reveal_timestamps = base_query
        .where(event_type: 'Reveal-Seller-Details')
        .where.not(buyer_id: nil)
        .pluck(:created_at)
        .map { |ts| ts&.iso8601 }

      # Get conversion tracking (guest to authenticated) - from base query
      conversion_events = base_all_reveal_events
        .where("metadata->>'converted_from_guest' = 'true'")
        .order(created_at: :desc)
      
      conversion_count = conversion_events.count
      conversion_timestamps = conversion_events.pluck(:created_at).map { |ts| ts&.iso8601 }

      # Get post-login redirect reveals - from base query
      post_login_reveals = base_all_reveal_events
        .where("metadata->>'post_login_reveal' = 'true'")
        .order(created_at: :desc)
      
      post_login_reveal_count = post_login_reveals.count
      post_login_reveal_timestamps = post_login_reveals.pluck(:created_at).map { |ts| ts&.iso8601 }

      # Get guest attempts that triggered login modal - from base query
      guest_login_attempts = base_all_reveal_events
        .where(buyer_id: nil)
        .where("metadata->>'triggered_login_modal' = 'true'")
        .order(created_at: :desc)
      
      guest_login_attempt_count = guest_login_attempts.count
      guest_login_attempt_timestamps = guest_login_attempts.pluck(:created_at).map { |ts| ts&.iso8601 }

      # Get reveal events by source (using base query to ensure exclusion)
      guest_attempt_reveals = base_all_reveal_events
        .where("metadata->>'source' = ? OR metadata->>'source' = ?", 'guest_attempt', 'post_login_redirect')
        .order(created_at: :desc)
      
      authenticated_user_reveals = base_all_reveal_events
        .where("metadata->>'source' = ?", 'authenticated_user')
        .order(created_at: :desc)
      
      post_login_redirect_reveals = base_all_reveal_events
        .where("metadata->>'source' = ?", 'post_login_redirect')
        .order(created_at: :desc)

      # Calculate conversion rate
      conversion_rate = guest_login_attempt_count > 0 ? 
        (conversion_count.to_f / guest_login_attempt_count * 100).round(2) : 0.0

      # Get top ads by reveal clicks with comprehensive metrics (excluding internal users)
      reveal_counts_by_ad = base_query
        .where(event_type: 'Reveal-Seller-Details')
        .group(:ad_id)
        .count
      
      # Get top 10 ads by reveal count
      top_ad_ids = reveal_counts_by_ad
        .sort_by { |_ad_id, count| -count }
        .first(10)
        .map { |ad_id, _count| ad_id }
      
      # Build comprehensive ad analytics
      top_ads_by_reveals = top_ad_ids.map do |ad_id|
        ad = Ad.find_by(id: ad_id)
        next nil unless ad
        
        # Get all click events for this ad (excluding internal users)
        ad_click_events = base_query.where(ad_id: ad_id)
        ad_clicks = ad_click_events.where(event_type: 'Ad-Click').count
        reveal_clicks = ad_click_events.where(event_type: 'Reveal-Seller-Details').count
        
        # Get reveal breakdown
        guest_reveals_for_ad = ad_click_events
          .where(event_type: 'Reveal-Seller-Details')
          .where(buyer_id: nil)
          .count
        authenticated_reveals_for_ad = ad_click_events
          .where(event_type: 'Reveal-Seller-Details')
          .where.not(buyer_id: nil)
          .count
        
        # Get conversions for this ad
        conversions_for_ad = ad_click_events
          .where(event_type: 'Reveal-Seller-Details')
          .where("metadata->>'converted_from_guest' = 'true'")
          .count
        
        # Calculate click-to-reveal conversion rate
        click_to_reveal_rate = ad_clicks > 0 ? 
          (reveal_clicks.to_f / ad_clicks * 100).round(2) : 0.0
        
        # Get seller info
        seller = ad.seller
        seller_name = seller&.enterprise_name || seller&.fullname || 'Unknown Seller'
        
        {
          ad_id: ad_id,
          ad_title: ad.title || 'Unknown Ad',
          ad_image_url: ad.first_media_url,
          category_name: ad.category&.name || 'Uncategorized',
          seller_name: seller_name,
          seller_id: ad.seller_id,
          # Click metrics
          total_click_events: ad_click_events.count,
          ad_clicks: ad_clicks,
          reveal_clicks: reveal_clicks,
          # Reveal breakdown
          guest_reveals: guest_reveals_for_ad,
          authenticated_reveals: authenticated_reveals_for_ad,
          conversions: conversions_for_ad,
          # Conversion rates
          click_to_reveal_rate: click_to_reveal_rate
        }
      end.compact

      # Apply additional email exclusions at SQL level for better performance
      # The excluding_internal_users scope should already handle this, but we ensure it's applied
      # Include hardcoded exclusions
      hardcoded_excluded_emails = ['sales@example.com', 'shangwejunior5@gmail.com']
      hardcoded_excluded_domains = ['example.com']
      excluded_email_patterns = (hardcoded_excluded_emails + hardcoded_excluded_domains + InternalUserExclusion.active
                                                     .by_type('email_domain')
                                                     .pluck(:identifier_value)).uniq
      
      if excluded_email_patterns.any?
        excluded_email_patterns.each do |pattern|
          pattern_lower = pattern.downcase
          
          # Exact email match
          filtered_query = filtered_query.where(
            "(metadata->>'user_email' IS NULL OR LOWER(metadata->>'user_email') != ?)",
            pattern_lower
          )
          
          # Domain match
          if pattern.include?('@')
            domain = pattern.split('@').last&.downcase
            if domain.present?
              filtered_query = filtered_query.where(
                "(metadata->>'user_email' IS NULL OR LOWER(metadata->>'user_email') NOT LIKE ?)",
                "%@#{domain}"
              )
            end
          else
            # Domain-only pattern (e.g., "example.com")
            filtered_query = filtered_query.where(
              "(metadata->>'user_email' IS NULL OR LOWER(metadata->>'user_email') NOT LIKE ?)",
              "%@#{pattern_lower}"
            )
          end
        end
      end
      
      # Get recent click events with user details (with pagination)
      page = params[:page].to_i
      page = 1 if page < 1
      per_page = params[:per_page].to_i
      per_page = 50 if per_page < 1 || per_page > 100 # Default 50, max 100
      
      # Apply filters to paginated query
      total_events_count = filtered_query.count
      total_pages = (total_events_count.to_f / per_page).ceil
      
      offset = (page - 1) * per_page
      
      recent_click_events = filtered_query
        .order(created_at: :desc)
        .offset(offset)
        .limit(per_page)
        .includes(:buyer, :ad)
        .map do |event|
          metadata = event.metadata || {}
          device_fingerprint = metadata['device_fingerprint'] || metadata[:device_fingerprint] || {}
          
          # Get buyer info if exists
          buyer_info = nil
          if event.buyer_id && event.buyer
            buyer = event.buyer
            buyer_info = {
              id: buyer.id,
              name: buyer.fullname,
              email: buyer.email,
              username: buyer.username,
              phone: buyer.phone_number
            }
          end
          
          # Extract user info from metadata (for sellers or when buyer_id is nil but user_id exists)
          user_info_from_metadata = nil
          if metadata['user_id'] || metadata[:user_id]
            user_info_from_metadata = {
              id: metadata['user_id'] || metadata[:user_id],
              role: metadata['user_role'] || metadata[:user_role],
              email: metadata['user_email'] || metadata[:user_email],
              username: metadata['user_username'] || metadata[:user_username]
            }
          end
          
          {
            id: event.id,
            event_type: event.event_type,
            ad_id: event.ad_id,
            ad_title: event.ad&.title || 'Unknown Ad',
            ad_image_url: event.ad&.first_media_url,
            created_at: event.created_at&.iso8601,
            # User information
            buyer_id: event.buyer_id,
            buyer_info: buyer_info,
            user_info: user_info_from_metadata,
            # Authentication status
            was_authenticated: metadata['was_authenticated'] || metadata[:was_authenticated] || false,
            is_guest: metadata['is_guest'] || metadata[:is_guest] || !event.buyer_id,
            # Device information
            device_hash: metadata['device_hash'] || metadata[:device_hash],
            user_agent: metadata['user_agent'] || metadata[:user_agent],
            platform: device_fingerprint['platform'] || device_fingerprint[:platform],
            screen_size: device_fingerprint['screen_width'] && device_fingerprint['screen_height'] ?
              "#{device_fingerprint['screen_width']}x#{device_fingerprint['screen_height']}" : 
              (device_fingerprint[:screen_width] && device_fingerprint[:screen_height] ?
                "#{device_fingerprint[:screen_width]}x#{device_fingerprint[:screen_height]}" : nil),
            language: device_fingerprint['language'] || device_fingerprint[:language],
            timezone: device_fingerprint['timezone'] || device_fingerprint[:timezone],
            # Conversion tracking
            converted_from_guest: metadata['converted_from_guest'] || metadata[:converted_from_guest] || false,
            post_login_reveal: metadata['post_login_reveal'] || metadata[:post_login_reveal] || false,
            triggered_login_modal: metadata['triggered_login_modal'] || metadata[:triggered_login_modal] || false,
            source: metadata['source'] || metadata[:source]
          }
        end

      response_data = {
        # Totals (from base query excluding internal users)
        total_click_events: base_all_click_events.count,
        total_reveal_events: base_all_reveal_events.count,
        total_ad_clicks: base_all_ad_clicks.count,
        guest_reveals: guest_reveals,
        authenticated_reveals: authenticated_reveals,
        conversion_count: conversion_count,
        conversion_rate: conversion_rate,
        post_login_reveal_count: post_login_reveal_count,
        guest_login_attempt_count: guest_login_attempt_count,

        # Timestamps for frontend filtering
        click_events_timestamps: click_events_timestamps,
        reveal_events_timestamps: reveal_events_timestamps,
        ad_clicks_timestamps: ad_clicks_timestamps,
        guest_reveal_timestamps: guest_reveal_timestamps,
        authenticated_reveal_timestamps: authenticated_reveal_timestamps,
        conversion_timestamps: conversion_timestamps,
        post_login_reveal_timestamps: post_login_reveal_timestamps,
        guest_login_attempt_timestamps: guest_login_attempt_timestamps,

        # Top performing ads
        top_ads_by_reveals: top_ads_by_reveals,
        
        # Recent click events with user details (paginated)
        recent_click_events: recent_click_events,
        recent_click_events_pagination: {
          page: page,
          per_page: per_page,
          total_count: total_events_count,
          total_pages: total_pages,
          has_next_page: page < total_pages,
          has_prev_page: page > 1
        }
      }

      render json: response_data
    rescue => e
      Rails.logger.error "Click events analytics error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { error: 'Internal server error', details: e.message }, status: 500
    end
  end

  private

  def authenticate_sales_user
    @current_sales_user = SalesAuthorizeApiRequest.new(request.headers).result
    unless @current_sales_user
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end
end

