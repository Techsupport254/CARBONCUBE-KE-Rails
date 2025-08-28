class Admin::CmsPagesController < ApplicationController
    before_action :authenticate_admin
    before_action :set_cms_page, only: [:show, :update, :destroy]
  
    def index
      @cms_pages = CmsPage.all
      render json: @cms_pages
    end
  
    def show
      render json: @cms_page
    end
  
    def create
      @cms_page = CmsPage.new(cms_page_params)
      if @cms_page.save
        render json: @cms_page, status: :created
      else
        render json: @cms_page.errors, status: :unprocessable_entity
      end
    end
  
    def update
      if @cms_page.update(cms_page_params)
        render json: @cms_page
      else
        render json: @cms_page.errors, status: :unprocessable_entity
      end
    end
  
    def destroy
      @cms_page.destroy
      head :no_content
    end
  
    private
  
    def set_cms_page
      @cms_page = CmsPage.find(params[:id])
    end
  
    def cms_page_params
      params.require(:cms_page).permit(:title, :content, :slug, :status)
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
  