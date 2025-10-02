class IssuesController < ApplicationController
  before_action :authenticate_user, except: [:index, :show, :create]
  before_action :set_issue, only: [:show, :update, :destroy, :assign, :add_comment, :add_attachment]
  before_action :ensure_admin, only: [:admin_index, :assign, :destroy]
  
  # Public endpoints
  def index
    @issues = Issue.public_visible.recent.includes(:assigned_to, :issue_comments)
    @issues = @issues.by_status(params[:status]) if params[:status].present?
    @issues = @issues.by_category(params[:category]) if params[:category].present?
    @issues = @issues.by_priority(params[:priority]) if params[:priority].present?
    
    render json: {
      issues: @issues.map { |issue| issue_json(issue) },
      meta: {
        total: @issues.count,
        statuses: Issue.statuses.keys,
        categories: Issue.categories.keys,
        priorities: Issue.priorities.keys
      }
    }
  end
  
  def show
    if @issue.public_visible? || (current_user&.is_a?(Admin))
      render json: {
        issue: issue_json(@issue, include_comments: true, include_attachments: true)
      }
    else
      render json: { error: 'Issue not found or not accessible' }, status: :not_found
    end
  end
  
  def create
    @issue = Issue.new(issue_params)
    @issue.public_visible = true
    
    # Set user if authenticated
    if current_user
      @issue.user = current_user
      @issue.user_type = current_user.class.name
    end
    
    # Generate device UUID if not provided
    @issue.device_uuid ||= generate_device_uuid
    
    if @issue.save
      render json: {
        issue: issue_json(@issue),
        message: 'Issue submitted successfully. You will receive a confirmation email shortly.'
      }, status: :created
    else
      render json: {
        errors: @issue.errors.full_messages
      }, status: :unprocessable_entity
    end
  end
  
  # Admin endpoints
  def admin_index
    @issues = Issue.recent.includes(:assigned_to, :issue_comments, :issue_attachments)
    @issues = @issues.by_status(params[:status]) if params[:status].present?
    @issues = @issues.by_category(params[:category]) if params[:category].present?
    @issues = @issues.by_priority(params[:priority]) if params[:priority].present?
    @issues = @issues.assigned_to_admin(params[:assigned_to]) if params[:assigned_to].present?
    
    render json: {
      issues: @issues.map { |issue| issue_json(issue, include_comments: true) },
      meta: {
        total: @issues.count,
        status_counts: Issue.group(:status).count,
        category_counts: Issue.group(:category).count,
        priority_counts: Issue.group(:priority).count,
        assigned_counts: Issue.where.not(assigned_to_id: nil).group(:assigned_to_id).count
      }
    }
  end
  
  def update
    if @issue.update(issue_params)
      render json: {
        issue: issue_json(@issue),
        message: 'Issue updated successfully'
      }
    else
      render json: {
        errors: @issue.errors.full_messages
      }, status: :unprocessable_entity
    end
  end
  
  def assign
    admin = Admin.find(params[:admin_id])
    @issue.update(assigned_to: admin)
    
    render json: {
      issue: issue_json(@issue),
      message: "Issue assigned to #{admin.fullname || admin.email}"
    }
  end
  
  def add_comment
    @comment = @issue.issue_comments.build(comment_params)
    @comment.author = current_user
    
    if @comment.save
      render json: {
        comment: comment_json(@comment),
        message: 'Comment added successfully'
      }
    else
      render json: {
        errors: @comment.errors.full_messages
      }, status: :unprocessable_entity
    end
  end
  
  def add_attachment
    # Handle file upload
    if params[:file].present?
      attachment = @issue.issue_attachments.build(attachment_params)
      attachment.uploaded_by = current_user
      
      if attachment.save
        render json: {
          attachment: attachment_json(attachment),
          message: 'Attachment uploaded successfully'
        }
      else
        render json: {
          errors: attachment.errors.full_messages
        }, status: :unprocessable_entity
      end
    else
      render json: {
        errors: ['No file provided']
      }, status: :bad_request
    end
  end
  
  def destroy
    @issue.destroy
    render json: {
      message: 'Issue deleted successfully'
    }
  end
  
  # Statistics endpoint
  def statistics
    render json: {
      total_issues: Issue.count,
      pending_issues: Issue.pending.count,
      in_progress_issues: Issue.in_progress.count,
      completed_issues: Issue.completed.count,
      closed_issues: Issue.closed.count,
      rejected_issues: Issue.rejected.count,
      issues_by_category: Issue.group(:category).count,
      issues_by_priority: Issue.group(:priority).count,
      issues_by_status: Issue.group(:status).count,
      recent_issues: Issue.recent.limit(10).map { |issue| issue_json(issue) }
    }
  end
  
  private
  
  def set_issue
    @issue = Issue.find(params[:id])
  end
  
  def issue_params
    params.require(:issue).permit(
      :title, :description, :reporter_name, :reporter_email, 
      :status, :priority, :category, :public_visible, :device_uuid
    )
  end
  
  def comment_params
    params.require(:comment).permit(:content)
  end
  
  def attachment_params
    params.require(:attachment).permit(:file_name, :file_size, :file_type, :file_url)
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
      created_at: issue.created_at,
      updated_at: issue.updated_at,
      time_since_created: issue.time_since_created,
      time_since_updated: issue.time_since_updated,
      status_badge_color: issue.status_badge_color,
      priority_badge_color: issue.priority_badge_color,
      category_badge_color: issue.category_badge_color
    }
    
    if issue.assigned_to
      json[:assigned_to] = {
        id: issue.assigned_to.id,
        name: issue.assigned_to.fullname || issue.assigned_to.email,
        email: issue.assigned_to.email
      }
    end
    
    if include_comments
      json[:comments] = issue.issue_comments.recent.map { |comment| comment_json(comment) }
    end
    
    if include_attachments
      json[:attachments] = issue.issue_attachments.recent.map { |attachment| attachment_json(attachment) }
    end
    
    json
  end
  
  def comment_json(comment)
    {
      id: comment.id,
      content: comment.content,
      author_name: comment.author_name,
      author_role: comment.author_role,
      is_internal: comment.is_internal?,
      created_at: comment.created_at,
      time_ago: comment.time_ago
    }
  end
  
  def attachment_json(attachment)
    {
      id: attachment.id,
      file_name: attachment.file_name,
      file_size: attachment.file_size,
      file_type: attachment.file_type,
      file_url: attachment.file_url,
      formatted_file_size: attachment.formatted_file_size,
      is_image: attachment.is_image?,
      is_document: attachment.is_document?,
      uploaded_by_name: attachment.uploaded_by_name,
      created_at: attachment.created_at,
      time_ago: attachment.time_ago
    }
  end
  
  def ensure_admin
    unless current_user&.is_a?(Admin)
      render json: { error: 'Admin access required' }, status: :forbidden
    end
  end
  
  def generate_device_uuid
    # Generate a unique device UUID for tracking
    SecureRandom.uuid
  end

  def authenticate_user
    # Try authenticating as different user types
    Rails.logger.info "IssuesController: Attempting authentication..."
    
    @current_user = authenticate_seller || authenticate_buyer || authenticate_admin || authenticate_sales
    
    if @current_user
      Rails.logger.info "IssuesController: Authenticated as #{@current_user.class.name} with ID #{@current_user.id}"
    else
      Rails.logger.error "IssuesController: Authentication failed for all user types"
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end

  def authenticate_seller
    SellerAuthorizeApiRequest.new(request.headers).result
  rescue
    nil
  end

  def authenticate_buyer
    BuyerAuthorizeApiRequest.new(request.headers).result
  rescue
    nil
  end

  def authenticate_admin
    AdminAuthorizeApiRequest.new(request.headers).result
  rescue
    nil
  end

  def authenticate_sales
    SalesAuthorizeApiRequest.new(request.headers).result
  rescue
    nil
  end
end
