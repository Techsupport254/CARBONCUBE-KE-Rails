class AgeGroupsController < ApplicationController
  def index
    age_groups = AgeGroup.all.order(:id)
    render json: age_groups
  end
end
