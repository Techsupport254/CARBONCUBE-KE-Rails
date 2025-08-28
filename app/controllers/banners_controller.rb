class BannersController < ApplicationController
  # skip_before_action :authenticate_user! # Skip authentication for this action

  def index
    @banners = Banner.all
    render json: @banners # ActiveModelSerializers will automatically use the `BannerSerializer`
  end
  
end
