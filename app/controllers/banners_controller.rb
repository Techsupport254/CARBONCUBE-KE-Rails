class BannersController < ApplicationController
  # skip_before_action :authenticate_user! # Skip authentication for this action

  def index
    @banners = Rails.cache.fetch('public_banners', expires_in: 5.minutes) do
      Banner.all.to_a
    end
    expires_in 5.minutes, public: true
    render json: @banners # ActiveModelSerializers will automatically use the `BannerSerializer`
  end
end
