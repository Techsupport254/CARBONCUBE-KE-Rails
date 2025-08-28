class EmploymentsController < ApplicationController
  def index
    employments = Employment.all
    render json: employments
  end
end