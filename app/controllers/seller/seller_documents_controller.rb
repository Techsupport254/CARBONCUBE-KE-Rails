class Seller::SellerDocumentsController < ApplicationController
  before_action :authenticate_seller
  before_action :set_seller_document, only: [:show, :update, :destroy]

  # GET /seller/seller_documents
  def index
    @seller_documents = current_seller.seller_documents.includes(:document_type)
    render json: @seller_documents
  end

  # GET /seller/seller_documents/:id
  def show
    render json: @seller_document
  end

  # POST /seller/seller_documents
  def create
    @seller_document = current_seller.seller_documents.build(seller_document_params)

    if @seller_document.save
      render json: @seller_document, status: :created
    else
      render json: { errors: @seller_document.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /seller/seller_documents/:id
  def update
    if @seller_document.update(seller_document_params)
      render json: @seller_document
    else
      render json: { errors: @seller_document.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /seller/seller_documents/:id
  def destroy
    @seller_document.destroy
    head :no_content
  end

  private

  def set_seller_document
    @seller_document = current_seller.seller_documents.find(params[:id])
  end

  def seller_document_params
    params.permit(:document_type_id, :document_url, :document_expiry_date)
  end

  def authenticate_seller
    @current_seller = SellerAuthorizeApiRequest.new(request.headers).result
    unless @current_seller && @current_seller.is_a?(Seller)
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end

  def current_seller
    @current_seller
  end
end
