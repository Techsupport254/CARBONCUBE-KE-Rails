class CountiesController < ApplicationController
  def index
    counties = County.all.order(:name)
    render json: counties, each_serializer: CountySerializer
  end

  def sub_counties
    county = County.find(params[:id])
    sub_counties = county.sub_counties.order(:name)
    render json: sub_counties, each_serializer: SubCountySerializer
  end
end
