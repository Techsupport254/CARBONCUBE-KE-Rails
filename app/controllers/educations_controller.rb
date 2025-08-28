class EducationsController < ApplicationController
  def index
    educations = Education.all
    render json: educations
  end
end