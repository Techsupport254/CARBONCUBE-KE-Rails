class CountiesController < ApplicationController
  def index
    counties = Rails.cache.fetch('public_counties', expires_in: 24.hours) do
      County.all.order(:name).to_a
    end
    expires_in 1.hour, public: true
    render json: counties, each_serializer: CountySerializer
  end

  def sub_counties
    county = County.find(params[:id])
    sub_counties = county.sub_counties.order(:name)
    render json: sub_counties, each_serializer: SubCountySerializer
  end
end
