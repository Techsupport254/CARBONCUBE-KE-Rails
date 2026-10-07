class Sales::SellerFollowUpsController < ApplicationController
  before_action :authenticate_sales_user
  before_action :set_seller, only: [:index, :create]
  before_action :set_follow_up, only: [:update, :destroy]

  # GET /sales/sellers/:seller_id/follow_ups
  #   Per-seller timeline (nested route).
  # GET /sales/seller_follow_ups
  #   Worklist across sellers — filters: status=open|resolved|all,
  #   due=overdue|today|upcoming|all, type, seller_id.
  def index
    scope =
      if @seller
        @seller.seller_follow_ups
      else
        scoped_follow_ups
      end

    scope = apply_filters(scope)

    page = [params[:page]&.to_i || 1, 1].max
    per_page = [params[:per_page]&.to_i || 50, 200].min
    total_count = scope.count

    follow_ups = scope
      .includes(:seller, :sales_user, :seller_verification)
      .order(Arel.sql('follow_up_date IS NULL, follow_up_date ASC, occurred_at DESC'))
      .offset((page - 1) * per_page)
      .limit(per_page)

    render json: {
      follow_ups: follow_ups.map { |f| serialize_follow_up(f) },
      pagination: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil
      },
      summary: summary_counts(@seller ? @seller.seller_follow_ups : scoped_follow_ups)
    }
  end

  # POST /sales/sellers/:seller_id/follow_ups
  def create
    follow_up = @seller.seller_follow_ups.build(
      follow_up_params.merge(
        sales_user: @current_sales_user,
        actor_name: @current_sales_user.fullname.presence || @current_sales_user.email,
        occurred_at: params[:occurred_at].presence || Time.current,
        seller_verification_id: verification_id
      )
    )

    if follow_up.save
      render json: { follow_up: serialize_follow_up(follow_up) }, status: :created
    else
      render json: { error: 'Follow-up failed', details: follow_up.errors.full_messages },
             status: :unprocessable_entity
    end
  end

  # PATCH /sales/seller_follow_ups/:id
  # Edit notes/type/date or flip status (resolve/reopen).
  def update
    unless editable?(@follow_up)
      return render json: { error: 'Not allowed' }, status: :forbidden
    end

    if @follow_up.update(update_params)
      render json: { follow_up: serialize_follow_up(@follow_up) }
    else
      render json: { error: 'Update failed', details: @follow_up.errors.full_messages },
             status: :unprocessable_entity
    end
  end

  # DELETE /sales/seller_follow_ups/:id — leads/managers only.
  def destroy
    unless @current_sales_user.team_sales_dashboard_access?
      return render json: { error: 'Not allowed' }, status: :forbidden
    end

    @follow_up.destroy!
    head :no_content
  end

  private

  def authenticate_sales_user
    @current_sales_user = SalesAuthorizeApiRequest.new(request.headers).result
    unless @current_sales_user
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end

  def set_seller
    @seller = Seller.find_by(slug: params[:seller_id]) || Seller.find(params[:seller_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Seller not found' }, status: :not_found
  end

  def set_follow_up
    @follow_up = SellerFollowUp.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Follow-up not found' }, status: :not_found
  end

  # Reps edit their own entries; leads/managers edit anything in their scope.
  def editable?(follow_up)
    follow_up.sales_user_id == @current_sales_user.id ||
      @current_sales_user.team_sales_dashboard_access?
  end

  # Same visibility rules as the verification log: managers see all, leads see
  # their team, reps see their own.
  def scoped_follow_ups
    if @current_sales_user.full_sales_dashboard_access?
      SellerFollowUp.all
    elsif @current_sales_user.team_sales_dashboard_access?
      SellerFollowUp.where(sales_user_id: team_scope_ids)
    else
      SellerFollowUp.where(sales_user_id: @current_sales_user.id)
    end
  end

  def team_scope_ids
    @team_scope_ids ||= [@current_sales_user.id] + @current_sales_user.team_members.pluck(:id)
  end

  def apply_filters(scope)
    scope = scope.where(seller_id: params[:seller_id]) if params[:seller_id].present? && !@seller

    case params[:status]
    when 'open' then scope = scope.open
    when 'resolved' then scope = scope.resolved
    end

    case params[:due]
    when 'overdue' then scope = scope.overdue
    when 'today' then scope = scope.due_today
    when 'upcoming' then scope = scope.upcoming
    end

    if params[:type].present? &&
       SellerFollowUp.follow_up_types.key?(params[:type])
      scope = scope.where(follow_up_type: params[:type])
    end

    scope
  end

  def summary_counts(scope)
    {
      open_count: scope.open.count,
      overdue_count: scope.overdue.count,
      due_today_count: scope.due_today.count,
      open_issues_count: scope.open.issues.count
    }
  end

  def follow_up_params
    {
      follow_up_type: params[:follow_up_type].presence_in(SellerFollowUp.follow_up_types.keys) || 'note',
      notes: params[:notes]&.strip&.presence,
      follow_up_date: parsed_date(params[:follow_up_date]),
      status: params[:status].presence_in(SellerFollowUp::STATUSES) || 'open'
    }
  end

  def update_params
    permitted = {}
    if params.key?(:follow_up_type) &&
       SellerFollowUp.follow_up_types.key?(params[:follow_up_type].to_s)
      permitted[:follow_up_type] = params[:follow_up_type]
    end
    permitted[:notes] = params[:notes]&.strip&.presence if params.key?(:notes)
    permitted[:follow_up_date] = parsed_date(params[:follow_up_date]) if params.key?(:follow_up_date)
    permitted[:status] = params[:status] if params[:status].presence_in(SellerFollowUp::STATUSES)
    permitted
  end

  def parsed_date(value)
    Date.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  # Link to the verification visit only if it belongs to this seller — a
  # mistyped id shouldn't anchor the follow-up to the wrong shop.
  def verification_id
    return if params[:seller_verification_id].blank?

    @seller.seller_verifications.where(id: params[:seller_verification_id]).pick(:id)
  end

  def serialize_follow_up(follow_up)
    rep = follow_up.sales_user
    seller = follow_up.seller
    {
      id: follow_up.id,
      seller_id: follow_up.seller_id,
      seller_verification_id: follow_up.seller_verification_id,
      follow_up_type: follow_up.follow_up_type,
      notes: follow_up.notes,
      status: follow_up.status,
      follow_up_date: follow_up.follow_up_date&.iso8601,
      overdue: follow_up.follow_up_date.present? &&
               follow_up.follow_up_date < Date.current &&
               !follow_up.resolved?,
      occurred_at: follow_up.occurred_at&.iso8601,
      resolved_at: follow_up.resolved_at&.iso8601,
      created_at: follow_up.created_at&.iso8601,
      actor_name: follow_up.actor_name.presence || rep&.fullname.presence || rep&.email,
      sales_user: rep && { id: rep.id, fullname: rep.fullname, email: rep.email },
      seller: seller && {
        id: seller.id,
        enterprise_name: seller.enterprise_name,
        fullname: seller.fullname,
        location: seller.location
      }
    }
  end
end
