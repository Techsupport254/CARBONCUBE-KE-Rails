class Api::BannersController < ApplicationController
  # GET /api/banners
  def index
    @banners = Banner.active.order(:position)
    render json: @banners
  end
end
