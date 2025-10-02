class Admin::IssuesController < ApplicationController
  before_action :authenticate_admin
  before_action :set_issue, only: [:show, :update, :destroy, :assign, :add_comment, :add_attachment]

  # GET /admin/issues
  def admin_index
    @issues = Issue.includes(:user, :assigned_to, :issue_comments, :issue_attachments)
                   .order(created_at: :desc)
    
    # Apply filters
    @issues = @issues.where(status: params[:status]) if params[:status].present?
    @issues = @issues.where(category: params[:category]) if params[:category].present?
    @issues = @issues.where(priority: params[:priority]) if params[:priority].present?
    @issues = @issues.where(assigned_to_id: params[:assigned_to]) if params[:assigned_to].present?
    
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @issues = @issues.where(
        "title ILIKE ? OR description ILIKE ? OR reporter_name ILIKE ? OR reporter_email ILIKE ?",
        search_term, search_term, search_term, search_term
      )
    end

    # Simple pagination without Kaminari
    page = params[:page]&.to_i || 1
    per_page = params[:per_page]&.to_i || 20
    offset = (page - 1) * per_page
    
    total_count = @issues.count
    @issues = @issues.limit(per_page).offset(offset)
    total_pages = (total_count.to_f / per_page).ceil

    render json: {
      issues: @issues.map { |issue| issue_json(issue, include_comments: true, include_attachments: true) },
      meta: {
        current_page: page,
        total_pages: total_pages,
        total_count: total_count,
        per_page: per_page
      }
    }
  end

  # GET /admin/issues/:id
  def show
    render json: issue_json(@issue, include_comments: true, include_attachments: true)
  end

  # PATCH/PUT /admin/issues/:id
  def update
    old_status = @issue.status
    if @issue.update(issue_params)
      # Send email notification if status changed
      if old_status != @issue.status && @issue.reporter_email.present?
        IssueMailer.with(issue: @issue).status_updated.deliver_now
      end
      
      render json: issue_json(@issue, include_comments: true, include_attachments: true)
    else
      render json: { errors: @issue.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /admin/issues/:id
  def destroy
    @issue.destroy
    head :no_content
  end

  # POST /admin/issues/:id/assign
  def assign
    assigned_to_id = params[:assigned_to_id]
    
    if assigned_to_id.present?
      # Validate that the assigned user exists (could be Admin, Seller, or Buyer)
      assigned_user = find_user_by_id(assigned_to_id)
      if assigned_user
        @issue.update(assigned_to_id: assigned_to_id)
        render json: { message: 'Issue assigned successfully', issue: issue_json(@issue) }
      else
        render json: { error: 'User not found' }, status: :not_found
      end
    else
      @issue.update(assigned_to_id: nil)
      render json: { message: 'Issue unassigned successfully', issue: issue_json(@issue) }
    end
  end

  # POST /admin/issues/:id/add_comment
  def add_comment
    @comment = @issue.issue_comments.build(comment_params)
    @comment.author = current_admin
    @comment.author_type = 'Admin'

    if @comment.save
      render json: {
        message: 'Comment added successfully',
        comment: {
          id: @comment.id,
          content: @comment.content,
          commenter_name: @comment.author_name,
          commenter_type: @comment.author_role,
          created_at: @comment.created_at,
          time_ago: @comment.time_ago
        }
      }
    else
      render json: { errors: @comment.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # POST /admin/issues/:id/add_attachment
  def add_attachment
    @attachment = @issue.issue_attachments.build(attachment_params)
    @attachment.uploaded_by = current_admin
    @attachment.uploaded_by_type = 'Admin'

    if @attachment.save
      render json: {
        message: 'Attachment added successfully',
        attachment: {
          id: @attachment.id,
          file_name: @attachment.file_name,
          file_size: @attachment.file_size,
          file_type: @attachment.file_type,
          file_url: @attachment.file_url,
          uploaded_by_name: @attachment.uploaded_by&.fullname || @attachment.uploaded_by&.username,
          created_at: @attachment.created_at
        }
      }
    else
      render json: { errors: @attachment.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # GET /admin/issues/statistics
  def statistics
    stats = {
      total_issues: Issue.count,
      pending_issues: Issue.where(status: 'pending').count,
      in_progress_issues: Issue.where(status: 'in_progress').count,
      completed_issues: Issue.where(status: 'completed').count,
      closed_issues: Issue.where(status: 'closed').count,
      rejected_issues: Issue.where(status: 'rejected').count,
      urgent_issues: Issue.where(priority: 'urgent').count,
      high_priority_issues: Issue.where(priority: 'high').count,
      bug_reports: Issue.where(category: 'bug').count,
      feature_requests: Issue.where(category: 'feature_request').count,
      security_issues: Issue.where(category: 'security').count,
      recent_issues: Issue.where('created_at >= ?', 7.days.ago).count,
      assigned_issues: Issue.where.not(assigned_to_id: nil).count,
      unassigned_issues: Issue.where(assigned_to_id: nil).count
    }

    render json: stats
  end

  private

  def set_issue
    @issue = Issue.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Issue not found' }, status: :not_found
  end

  def issue_params
    params.require(:issue).permit(
      :title, :description, :status, :priority, :category, 
      :public_visible, :assigned_to_id
    )
  end

  def comment_params
    params.require(:comment).permit(:content)
  end

  def attachment_params
    params.require(:attachment).permit(:file_name, :file_size, :file_type, :file_url)
  end

  def authenticate_admin
    @current_user = AdminAuthorizeApiRequest.new(request.headers).result
    unless @current_user && @current_user.is_a?(Admin)
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end

  def current_admin
    @current_user
  end

  def find_user_by_id(user_id)
    # Try to find user in different models
    Admin.find_by(id: user_id) || 
    Seller.find_by(id: user_id) || 
    Buyer.find_by(id: user_id)
  end

  def issue_json(issue, include_comments: false, include_attachments: false)
    json = {
      id: issue.id,
      issue_number: issue.issue_number,
      title: issue.title,
      description: issue.description,
      reporter_name: issue.reporter_name,
      reporter_email: issue.reporter_email,
      status: issue.status,
      priority: issue.priority,
      category: issue.category,
      public_visible: issue.public_visible,
      device_uuid: issue.device_uuid,
      user_role: issue.user_role,
      internal_user: issue.internal_user?,
      external_user: issue.external_user?,
      assigned_to_id: issue.assigned_to_id,
      assigned_to_name: issue.assigned_to&.fullname || issue.assigned_to&.username,
      created_at: issue.created_at,
      updated_at: issue.updated_at,
      time_since_created: issue.time_since_created,
      time_since_updated: issue.time_since_updated,
      status_badge_color: issue.status_badge_color,
      priority_badge_color: issue.priority_badge_color,
      category_badge_color: issue.category_badge_color
    }

    if include_comments
      json[:comments] = issue.issue_comments.includes(:author).order(created_at: :asc).map do |comment|
        {
          id: comment.id,
          content: comment.content,
          commenter_name: comment.author_name,
          commenter_type: comment.author_role,
          created_at: comment.created_at,
          time_ago: comment.time_ago
        }
      end
    end

    if include_attachments
      json[:attachments] = issue.issue_attachments.includes(:uploaded_by).order(created_at: :asc).map do |attachment|
        {
          id: attachment.id,
          file_name: attachment.file_name,
          file_size: attachment.file_size,
          file_type: attachment.file_type,
          file_url: attachment.file_url,
          uploaded_by_name: attachment.uploaded_by&.fullname || attachment.uploaded_by&.username,
          created_at: attachment.created_at
        }
      end
    end

    json
  end
end
