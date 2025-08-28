class Admin::FaqsController < ApplicationController
  before_action :authenticate_admin
  before_action :set_faq, only: [:show, :update, :destroy]

  # GET /admin/faqs
  def index
    @faqs = Faq.all
    render json: @faqs
  end

  # GET /admin/faqs/:id
  def show
    render json: @faq
  end

  # POST /admin/faqs
  def create
    @faq = Faq.new(faq_params)
    if @faq.save
      render json: @faq, status: :created
    else
      render json: @faq.errors, status: :unprocessable_entity
    end
  end

  # PUT /admin/faqs/:id
  def update
    if @faq.update(faq_params)
      render json: @faq
    else
      render json: @faq.errors, status: :unprocessable_entity
    end
  end

  # DELETE /admin/faqs/:id
  def destroy
    @faq.destroy
    head :no_content
  end

  private

  def set_faq
    @faq = Faq.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'FAQ not found' }, status: :not_found
  end

  def faq_params
    params.require(:faq).permit(:question, :answer)
  end

  def authenticate_admin
    @current_user = AdminAuthorizeApiRequest.new(request.headers).result
    unless @current_user && @current_user.is_a?(Admin)
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end

  def current_admin
    @current_user
  end
end
