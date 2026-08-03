class Seller::PricingTemplatesController < ApplicationController
  before_action :authenticate_seller_or_sales
  before_action :set_template, only: [:update, :destroy]

  def index
    templates = current_seller.seller_pricing_templates
                              .includes(:category, :subcategory)
                              .order(created_at: :desc)

    render json: { success: true, data: templates.as_json(include: [:category, :subcategory]) }
  end

  def default
    template = SellerPricingTemplate.resolve(
      current_seller,
      category_id: params[:category_id],
      subcategory_id: params[:subcategory_id]
    )

    if template
      render json: { success: true, data: template.as_json(include: [:category, :subcategory]) }
    else
      render json: { success: true, data: nil }
    end
  end

  def create
    # Find or initialize by the scope to keep one template per scope.
    template = current_seller.seller_pricing_templates.find_or_initialize_by(
      category_id: pricing_template_params[:category_id],
      subcategory_id: pricing_template_params[:subcategory_id]
    )

    template.assign_attributes(pricing_template_params)

    if template.save
      render json: { success: true, data: template.as_json(include: [:category, :subcategory]) }
    else
      render json: { success: false, errors: template.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @template.update(pricing_template_params)
      render json: { success: true, data: @template.as_json(include: [:category, :subcategory]) }
    else
      render json: { success: false, errors: @template.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @template.destroy
    render json: { success: true }
  end

  def product_categories
    category_ids = current_seller.ads
                                  .where.not(category_id: nil)
                                  .distinct
                                  .pluck(:category_id)

    render json: { success: true, data: category_ids }
  end

  def create_defaults
    categories = Category.includes(:subcategories).all
    created = 0

    categories.each do |category|
      service = category.name.to_s.match?(/service|leasing/i)
      pricing_unit = service ? 'project' : 'piece'

      # Category-level default
      category_template = current_seller.seller_pricing_templates
                                        .find_or_initialize_by(
                                          category_id: category.id,
                                          subcategory_id: nil
                                        )
      if category_template.new_record?
        category_template.assign_attributes(
          pricing_unit: pricing_unit,
          price_display_mode: 'public',
          price_tiers: []
        )
        created += 1 if category_template.save
      end

      # Subcategory-level defaults
      category.subcategories.each do |subcategory|
        sub_template = current_seller.seller_pricing_templates
                                     .find_or_initialize_by(
                                       category_id: category.id,
                                       subcategory_id: subcategory.id
                                     )
        next unless sub_template.new_record?

        sub_template.assign_attributes(
          pricing_unit: pricing_unit,
          price_display_mode: 'public',
          price_tiers: []
        )
        created += 1 if sub_template.save
      end
    end

    render json: { success: true, data: { created: created } }
  end

  private

  def authenticate_seller_or_sales
    user = AuthorizeApiRequest.new(request.headers).result

    @current_seller = case user
                      when Seller
                        user
                      when SalesUser
                        branch_id = request.headers['X-Branch-Id']
                        Branch.find_by(id: branch_id)&.seller
                      end

    unless @current_seller && @current_seller.is_a?(Seller)
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end

  def current_seller
    @current_seller
  end

  def set_template
    @template = current_seller.seller_pricing_templates.find_by(id: params[:id])
    render json: { error: 'Template not found' }, status: :not_found unless @template
  end

  def pricing_template_params
    params.require(:seller_pricing_template).permit(
      :category_id, :subcategory_id, :pricing_unit, :price_display_mode,
      price_tiers: [:min_quantity, :max_quantity, :label]
    )
  end
end
