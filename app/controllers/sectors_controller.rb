class SectorsController < ApplicationController
  def index
    sectors = Sector.all
    render json: sectors
  end
end