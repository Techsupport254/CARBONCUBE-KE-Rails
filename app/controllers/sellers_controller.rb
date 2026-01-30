class SellersController < ApplicationController
  before_action :authenticate_seller_for_completion, only: [:complete_registration]

  def complete_registration
    begin
      # Extract nested seller params if present, otherwise use direct params
      seller_data = params[:seller] || params
      
      # Get the current seller from authentication
      seller = @current_seller
      
      unless seller
        render json: { error: 'Not authorized' }, status: :unauthorized
        return
      end

      # Permit the allowed fields
      update_params = seller_data.permit(
        :fullname, :name, :phone_number, :phone, :secondary_phone_number, :email,
        :enterprise_name, :location, :business_registration_number,
        :gender, :city, :zipcode, :username, :description,
        :county_id, :sub_county_id, :age_group_id,
        :document_type_id, :document_expiry_date, :carbon_code
      ).reject { |k, v| v.blank? }

      # Map frontend field names to backend field names
      update_params[:fullname] = update_params[:name] if update_params[:name].present?
      update_params[:phone_number] = update_params[:phone] if update_params[:phone].present?
      
      # Remove the frontend field names after mapping
      update_params.delete(:name)
      update_params.delete(:phone)

      # Resolve carbon_code string to carbon_code_id (for OAuth completion modal)
      carbon_code_param = update_params.delete(:carbon_code)
      carbon_code = nil
      if carbon_code_param.present?
        carbon_code = CarbonCode.find_by("UPPER(TRIM(code)) = ?", carbon_code_param.to_s.strip.upcase)
        if carbon_code.nil?
          render json: { errors: { carbon_code: ["Carbon code is invalid."] } }, status: :unprocessable_entity
          return
        end
        unless carbon_code.valid_for_use?
          msg = carbon_code.expired? ? "This Carbon code has expired." : "This Carbon code has reached its usage limit."
          render json: { errors: { carbon_code: [msg] } }, status: :unprocessable_entity
          return
        end
        update_params[:carbon_code_id] = carbon_code.id
      end

      # Remove any unexpected fields
      unexpected_fields = ['created_at', 'updated_at', 'id', 'birthdate']
      unexpected_fields.each { |field| update_params.delete(field) }

      # Additional filtering for empty strings and null values
      update_params = update_params.reject { |k, v| v.nil? || v.to_s.strip.empty? }

      if seller.update(update_params)
        # Increment carbon code usage when applied via completion modal
        carbon_code&.increment!(:times_used)
        seller_data = SellerSerializer.new(seller.reload).as_json
        # Check if email is verified
        email_verified = EmailOtp.exists?(email: seller.email, verified: true)
        seller_data[:email_verified] = email_verified
        render json: seller_data, status: :ok
      else
        Rails.logger.error "Seller completion failed with errors: #{seller.errors.full_messages.join(', ')}"
        render json: { errors: seller.errors.full_messages }, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error "Complete registration error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { error: "Failed to complete registration: #{e.message}" }, status: :internal_server_error
    end
  end

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

  private

  def authenticate_seller_for_completion
    @current_seller = SellerAuthorizeApiRequest.new(request.headers).result
    unless @current_seller && @current_seller.is_a?(Seller)
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end
end