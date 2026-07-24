class Seller::CatalogsController < ApplicationController
  require 'csv'
  require 'redcarpet'

  helper_method :render_catalog_markdown

  # GET /seller/catalog/search
  def search
    query = params[:query] || params[:q]
    subcategory = params[:subcategory] || params[:category] || 'phones'
    category_name = params[:categoryName]
    return render json: { phones: [] } if query.blank?

    devices = DeviceCatalogService.search(query, subcategory, category_name)
    
    render json: {
      phones: devices.map do |p|
        {
          title: p['title'],
          slug: p['slug'],
          brand: p['brand'],
          specifications: p['specifications']
        }
      end
    }
  end

  # GET /seller/catalog/brands
  def brands
    subcategory = params[:subcategory] || params[:category] || 'phones'
    category_name = params[:categoryName]
    render json: { brands: DeviceCatalogService.brands(subcategory, category_name) }
  end

  # GET /seller/catalog/models
  def models
    brand = params[:brand]
    subcategory = params[:subcategory] || params[:category] || 'phones'
    category_name = params[:categoryName]
    return render json: { models: [] } if brand.blank?
    
    render json: { models: DeviceCatalogService.models_for_brand(brand, subcategory, category_name) }
  end

  # GET /seller/catalog/model/:slug
  def show
    if params[:slug].blank? && (request.format.html? || params[:format] == 'csv')
      render_seller_catalog_document
      return
    end

    subcategory = params[:subcategory] || params[:category] || 'phones'
    category_name = params[:categoryName]
    device = DeviceCatalogService.find_by_slug(params[:slug], subcategory, category_name)
    if device
      render json: device
    else
      render json: { error: 'Model not found' }, status: :not_found
    end
  end

  private

  def render_seller_catalog_document
    @seller = seller_from_token_param
    return render plain: 'Not Authorized', status: :unauthorized unless @seller

    @products = @seller.ads.includes(:category, :subcategory).order(created_at: :desc)

    if params[:format] == 'csv'
      send_data(
        build_catalog_csv(@products),
        filename: "#{@seller.enterprise_name.to_s.parameterize.presence || 'seller-catalog'}-catalog.csv",
        type: 'text/csv'
      )
    else
      render :show, layout: false
    end
  end

  def seller_from_token_param
    token = params[:token].to_s.strip
    return nil if token.blank?

    SellerAuthorizeApiRequest.new({ 'Authorization' => "Bearer #{token}" }).result
  rescue StandardError
    nil
  end

  def build_catalog_csv(products)
    CSV.generate(headers: true) do |csv|
      csv << ['#', 'Title', 'Category', 'Subcategory', 'Price (KES)', 'Deleted', 'Description']
      products.each_with_index do |product, index|
        csv << [
          index + 1,
          product.title,
          product.try(:category_name),
          product.try(:subcategory_name),
          product.price,
          product.deleted ? 'Yes' : 'No',
          product.description.to_s.squish
        ]
      end
    end
  end

  def authenticate_seller
    @current_user = SellerAuthorizeApiRequest.new(request.headers).result
    unless @current_user && @current_user.is_a?(Seller)
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end

  def render_catalog_markdown(content)
    markdown = content.to_s.strip
    return '' if markdown.blank?

    renderer = Redcarpet::Render::HTML.new(
      filter_html: true,
      hard_wrap: true,
      link_attributes: { rel: 'nofollow noopener noreferrer', target: '_blank' }
    )
    parser = Redcarpet::Markdown.new(
      renderer,
      autolink: true,
      fenced_code_blocks: true,
      no_intra_emphasis: true,
      strikethrough: true,
      tables: true
    )

    helpers.sanitize(
      parser.render(markdown),
      tags: %w[p br strong em ul ol li h1 h2 h3 h4 h5 h6 blockquote code pre a],
      attributes: %w[href rel target]
    ).html_safe
  end
end
