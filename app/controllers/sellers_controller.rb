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
        email_verified = EmailOtp.for_email(seller.email).exists?(verified: true)
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
                      .select(:id, :enterprise_name, :fullname, :slug, :created_at)
                      .order(:enterprise_name)
      
      # Convert enterprise names to slugs for sitemap
      sellers_data = sellers.map do |seller|
        {
          id: seller.id,
          name: seller.fullname,
          enterprise_name: seller.enterprise_name,
          slug: seller.url_slug,
          created_at: seller.created_at
        }
      end
      
      render json: sellers_data
    else
      # Parse and validate pagination
      page = [(params[:page] || 1).to_i, 1].max
      limit = [[(params[:limit] || 50).to_i, 1].max, 200].min
      offset = (page - 1) * limit

      # Coordinate bucketing: round to 2 decimal places (~1.1 km) to maximize cache hit rates
      lat = Float(params[:lat], exception: false)
      lng = Float(params[:lng], exception: false)
      has_coords = lat&.between?(-90, 90) && lng&.between?(-180, 180)
      lat_rounded = has_coords ? lat.round(2) : nil
      lng_rounded = has_coords ? lng.round(2) : nil

      cache_key = "sellers_index_v2_p#{page}_l#{limit}_q#{Digest::MD5.hexdigest(params[:query].to_s)}_c#{params[:category_id]}_lat#{lat_rounded}_lng#{lng_rounded}_#{Time.current.to_i / 300}"

      response_data = Rails.cache.fetch(cache_key, expires_in: 5.minutes, race_condition_ttl: 10.seconds) do
        # Eager load all associations accessed by SellerSerializer to completely avoid N+1 queries
        sellers_scope = Seller.active
                              .includes(
                                :categories,
                                :seller_documents,
                                { seller_tier: :tier },
                                :tier,
                                :county,
                                :sub_county,
                                :partner,
                                :branches,
                                :carbon_code
                              )

        # Optional keyword search
        if params[:query].present?
          q = "%#{params[:query].to_s.strip}%"
          sellers_scope = sellers_scope.where("sellers.enterprise_name ILIKE :q OR sellers.fullname ILIKE :q OR sellers.description ILIKE :q", q: q)
        end

        # Optional category filter
        if params[:category_id].present?
          sellers_scope = sellers_scope.joins(:categories).where(categories: { id: params[:category_id] })
        end

        # Fast count before adding select/order to avoid running heavy distance math during COUNT
        total_count = sellers_scope.count

        # Optional "near me" ordering — when client passes GPS coords, order by
        # Haversine distance (km) to the seller's nearest geocoded branch and expose
        # it as `distance_km` on each serialized seller.
        if has_coords
          distance_sql = <<~SQL.squish
            (SELECT MIN(6371 * 2 * ASIN(SQRT(
               POWER(SIN(RADIANS(#{lat} - branches.latitude) / 2), 2) +
               COS(RADIANS(branches.latitude)) * COS(RADIANS(#{lat})) *
               POWER(SIN(RADIANS(#{lng} - branches.longitude) / 2), 2))))
             FROM branches
             WHERE branches.seller_id = sellers.id
               AND branches.latitude IS NOT NULL
               AND branches.longitude IS NOT NULL)
          SQL
          sellers_scope = sellers_scope
            .select("sellers.*, #{distance_sql} AS distance_km")
            .order(Arel.sql('distance_km ASC NULLS LAST, enterprise_name ASC'))
        else
          sellers_scope = sellers_scope.order(:enterprise_name)
        end

        paged_sellers = sellers_scope.offset(offset).limit(limit)

        {
          sellers: paged_sellers.map { |seller| SellerSerializer.new(seller).as_json },
          pagination: {
            current_page: page,
            per_page: limit,
            total_count: total_count,
            total_pages: (total_count.to_f / limit).ceil
          }
        }
      end

      render json: response_data
    end
  end

  def ads
    seller = Seller.where(deleted: false).find_by(slug: params[:seller_id]) ||
             Seller.find_by(id: params[:seller_id])
    unless seller
      render json: { error: 'Seller not found' }, status: :not_found
      return
    end

    ads = seller.ads.active.includes(:category, :subcategory) # eager-load if needed

    # Always paginate — a seller with thousands of ads would otherwise
    # serialize the whole collection into one response.
    page = (params[:page] || 1).to_i
    limit = [(params[:limit] || 100).to_i, 200].min
    offset = (page - 1) * limit
    ads = ads.offset(offset).limit(limit)
    
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