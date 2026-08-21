class AdsController < ApplicationController
  # GET /ads
  def index
    per_page = params[:per_page]&.to_i || 100
    per_page = [per_page, 500].min # Cap at 500 for performance
    
    # Fetch ads from all active sellers (not just premium) with valid images
    # No caching to ensure true randomization on each request
    @ads = Ad.active.with_valid_images.joins(:seller)
             .where(sellers: { blocked: false, deleted: false, flagged: false })
             .where(flagged: false)
             .includes(
               :category,
               :subcategory,
               seller: { seller_tier: :tier }
             )
             .order(Arel.sql('RANDOM()'))
             .limit(per_page)

    render json: @ads, each_serializer: AdSerializer
  end

  # GET /ads/:id
  def show
    @ad = Ad.active.joins(:seller)
            .where(sellers: { blocked: false, deleted: false, flagged: false })
            .where(flagged: false)
            .includes(
              :category,
              :subcategory,
              :reviews,
              :offer_ads,
              seller: { seller_tier: :tier },
              offer_ads: :offer
            )
            .find_by_id_or_slug(params[:id])

    if @ad
      # Get similar products
      similar_products_data = SimilarProductsService.find_similar_products(@ad, limit: 15)

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
