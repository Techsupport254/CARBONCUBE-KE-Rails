class SellersController < ApplicationController
  def index
    # Check if this is for sitemap generation (backward compatibility)
    if params[:format] == 'xml' || params[:sitemap] == 'true'
      # Get all active sellers for sitemap generation
      sellers = Seller.where(deleted: false, blocked: false)
                      .select(:id, :enterprise_name, :fullname, :created_at)
                      .order(:enterprise_name)
      
      # Convert enterprise names to slugs for sitemap
      sellers_data = sellers.map do |seller|
        slug = seller.enterprise_name.downcase
                     .gsub(/[^a-z0-9\s]/, '') # Remove special characters
                     .gsub(/\s+/, '-')        # Replace spaces with hyphens
                     .strip
        
        {
          id: seller.id,
          name: seller.fullname,
          enterprise_name: seller.enterprise_name,
          slug: slug,
          created_at: seller.created_at
        }
      end
      
      render json: sellers_data
    else
      # Get all active sellers with full data
      sellers = Seller.active
                      .includes(:categories, :seller_documents, :seller_tier, :tier, :county, :sub_county)
                      .order(:enterprise_name)
      
      # Add pagination support (optional)
      if params[:page] && params[:limit]
        page = params[:page].to_i
        limit = params[:limit].to_i
        offset = (page - 1) * limit
        
        total_count = sellers.count
        sellers = sellers.offset(offset).limit(limit)
        
        render json: {
          sellers: sellers.map { |seller| SellerSerializer.new(seller).as_json },
          pagination: {
            current_page: page,
            per_page: limit,
            total_count: total_count,
            total_pages: (total_count.to_f / limit).ceil
          }
        }
      else
        render json: sellers, each_serializer: SellerSerializer
      end
    end
  end

  def ads
    seller = Seller.find(params[:seller_id])
    ads = seller.ads.active.includes(:category, :subcategory) # eager-load if needed
    
    # Add pagination support (only if page and limit are provided)
    if params[:page] && params[:limit]
      page = params[:page].to_i
      limit = params[:limit].to_i
      offset = (page - 1) * limit
      
      # Apply pagination
      ads = ads.offset(offset).limit(limit)
    end
    
    render json: ads.map { |ad| ad.as_json.merge(
      {
        media_urls: ad.media_urls, # Adjust to how you handle images
        category_name: ad.category&.name,
        subcategory_name: ad.subcategory&.name
      }
    ) }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Seller not found' }, status: :not_found
  end
end