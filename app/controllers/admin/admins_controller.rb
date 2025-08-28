class Admin::AdminsController < ApplicationController
  before_action :identify_admin

  def identify
    if @admin
      render json: { admin: @admin }, status: :ok
    else
      render json: { error: 'Admin not identified' }, status: :unauthorized
    end
  end

  private

  def identify_admin
    @admin = AdminAuthorizeApiRequest.new(request.headers).result
  rescue ExceptionHandler::InvalidToken, ExceptionHandler::MissingToken => e
    render json: { error: e.message }, status: :unauthorized
  end
end
