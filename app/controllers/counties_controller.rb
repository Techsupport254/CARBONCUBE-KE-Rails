class CountiesController < ApplicationController
  def index
    counties = County.all.select(:id, :name, :county_code)
    render json: counties
  end

  def sub_counties
    county = County.find(params[:id])
    render json: county.sub_counties.select(:id, :name, :sub_county_code)
  end
end
