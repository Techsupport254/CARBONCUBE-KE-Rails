# frozen_string_literal: true

# Authenticates the staff actor for /sales/* endpoints that the admin portal
# also calls. Tries the sales-rep token first (returns nil on failure), then
# the admin token (raises on failure — rescued to nil). The resolved actor is
# stored in @current_actor and may be a SalesUser or an Admin.
#
# Never assign @current_actor directly to a `sales_user` association — an
# Admin would raise AssociationTypeMismatch. Use `current_sales_user` for
# sales_user FK fields and `current_actor_name` for display attribution.
# Polymorphic references (e.g. PartnerInvite#invited_by) may take
# @current_actor as-is.
module SalesOrAdminAuthenticatable
  extend ActiveSupport::Concern

  include ActorAttribution

  private

  def authenticate_sales_or_admin
    @current_actor = SalesAuthorizeApiRequest.new(request.headers).result || authorize_admin
    render json: { error: 'Not Authorized' }, status: :unauthorized unless @current_actor
  end

  # The actor only when they're a sales rep — safe for sales_user FK columns.
  def current_sales_user
    sales_user_for(@current_actor)
  end

  # Display-name attribution for agent_name/actor_name fields.
  def current_actor_name
    actor_name_for(@current_actor)
  end

  def authorize_admin
    AdminAuthorizeApiRequest.new(request.headers).result
  rescue ExceptionHandler::InvalidToken, ExceptionHandler::MissingToken
    nil
  end
end
