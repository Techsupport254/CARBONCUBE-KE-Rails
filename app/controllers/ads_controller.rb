class AdsController < ApplicationController
  # GET /ads
  def index
    per_page = params[:per_page]&.to_i || 100
    per_page = [per_page, 200].min # Cap at 200 — serializer cost scales per row

    # Fetch ads from all active sellers (not just premium) with valid images.
    # The includes list covers every association AdSerializer/SellerSerializer
    # touches, so a page of cards costs O(1) queries instead of O(records).
    # ORDER BY RANDOM() would sort the whole table per request — instead keep
    # a cached pool of shuffled live-ad ids per minute and page through it;
    # each minute the pool reshuffles so the feed still rotates.
    pool = Rails.cache.fetch("ads_random_pool/#{Time.current.to_i / 60}", expires_in: 2.minutes) do
      Ad.active.with_valid_images.joins(:seller)
        .where(sellers: { blocked: false, deleted: false, flagged: false })
        .where(flagged: false)
        .pluck(:id)
        .shuffle
    end

    ids = pool.first(per_page)
    @ads = Ad.where(id: ids)
             .order(Arel.sql("array_position(ARRAY[#{ids.map(&:to_i).join(',')}]::bigint[], ads.id)"))
             .includes(
               :category,
               :subcategory,
               offer_ads: :offer,
               seller: [
                 { seller_tier: :tier },
                 :partner,
                 :categories,
                 :seller_documents,
                 :carbon_code,
                 :google_business_profile_connection
               ]
             )

    render json: @ads, each_serializer: AdSerializer
  end

  # GET /ads/:id
  def show
    ad_scope = Ad.active.joins(:seller)
                .where(sellers: { blocked: false, deleted: false, flagged: false })
                .where(flagged: false)
                .includes(
                  :category,
                  :subcategory,
                  reviews: :buyer,
                  offer_ads: :offer,
                  seller: [
                    { seller_tier: :tier },
                    :partner,
                    :categories,
                    :seller_documents,
                    :carbon_code,
                    :google_business_profile_connection
                  ]
                )
    param = params[:id].to_s
    if %w[null undefined].include?(param)
      render json: { error: 'Ad not found' }, status: :not_found
      return
    end

    @ad = ad_scope.find_by(slug: param) || ad_scope.find_by(id: param) || ad_scope.find_by_id_or_slug(param)

    if @ad
      unless @ad.has_valid_images?
        current_seller = begin
          SellerAuthorizeApiRequest.new(request.headers).result
        rescue StandardError
          nil
        end
        unless current_seller.is_a?(Seller) && current_seller.id.to_s == @ad.seller_id.to_s
          render json: { error: 'Ad not found' }, status: :not_found
          return
        end
      end

      # Get similar products — the matcher runs several ILIKE scans, so cache
      # per ad for a few minutes (same TTL family as related_ads_* caches).
      similar_products_data = Rails.cache.fetch(
        "similar_ads_#{@ad.id}", expires_in: 5.minutes
      ) do
        SimilarProductsService.find_similar_products(@ad, limit: 15)
      end

      # Render with similar products
      ad_data = AdSerializer.new(@ad).as_json
      ad_data[:similar_products] = similar_products_data

      render json: ad_data
      return
    end

    # Check if ad exists in database but is flagged or held
    flagged_ad = Ad.active.find_by_id_or_slug(params[:id])
    if flagged_ad
      cat_slug = flagged_ad.category ? Ad.slugify(flagged_ad.category.name) : nil
      subcat_slug = flagged_ad.subcategory ? Ad.slugify(flagged_ad.subcategory.name) : nil
      render json: {
        error: 'Listing under review',
        is_flagged: true,
        flagged: true,
        id: flagged_ad.id,
        slug: flagged_ad.url_slug,
        title: flagged_ad.title,
        name: flagged_ad.title,
        flag_notes: flagged_ad.flag_notes,
        seller_id: flagged_ad.seller_id,
        category_name: flagged_ad.category&.name,
        category_slug: cat_slug,
        subcategory_name: flagged_ad.subcategory&.name,
        subcategory_slug: subcat_slug
      }, status: :ok
      return
    end

    render json: { error: 'Ad not found' }, status: :not_found
  end
end
