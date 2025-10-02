class IssueMailer < ApplicationMailer
  default from: "Carbon Cube Kenya <#{ENV['BREVO_EMAIL']}>"

  def issue_created
    @issue = params[:issue]
    @user_name = @issue.reporter_name
    @issue_number = @issue.issue_number
    @issue_title = @issue.title
    @issue_description = @issue.description
    @issue_category = @issue.category&.humanize || 'Other'
    @issue_priority = @issue.priority&.humanize || 'Medium'
    @issue_status = @issue.status&.humanize || 'Pending'
    @submitted_at = @issue.created_at.strftime("%B %d, %Y at %I:%M %p")
    @tracking_url = "#{ENV['REACT_APP_SITE_URL']}/issues"
    
    mail(
      to: @issue.reporter_email,
      subject: "Issue #{@issue_number} Submitted Successfully - Carbon Cube Kenya"
    )
  end

  def status_updated
    @issue = params[:issue]
    @user_name = @issue.reporter_name
    @issue_number = @issue.issue_number
    @issue_title = @issue.title
    @old_status = @issue.previous_changes['status']&.first&.humanize || 'Unknown'
    @new_status = @issue.status.humanize
    @updated_at = @issue.updated_at.strftime("%B %d, %Y at %I:%M %p")
    @tracking_url = "#{ENV['REACT_APP_SITE_URL']}/issues"
    
    # Get status-specific message
    @status_message = get_status_message(@new_status)
    
    mail(
      to: @issue.reporter_email,
      subject: "Issue #{@issue_number} Status Updated to #{@new_status} - Carbon Cube Kenya"
    )
  end

  def comment_added
    @comment = params[:comment]
    @issue = @comment.issue
    @user_name = @issue.reporter_name
    @issue_number = @issue.issue_number
    @issue_title = @issue.title
    @comment_content = @comment.content
    @commenter_name = @comment.author_name
    @commenter_type = @comment.author_role
    @commented_at = @comment.created_at.strftime("%B %d, %Y at %I:%M %p")
    @tracking_url = "#{ENV['REACT_APP_SITE_URL']}/issues"
    
    mail(
      to: @issue.reporter_email,
      subject: "New Comment Added to Issue #{@issue_number} - Carbon Cube Kenya"
    )
  end

  private

  def get_status_message(status)
    case status.downcase
    when 'pending'
      "Your issue has been received and is currently under review by our team. We'll update you as soon as we have more information."
    when 'in_progress'
      "Great news! We've started working on your issue. Our development team is actively addressing the problem you reported."
    when 'completed'
      "Excellent! Your issue has been resolved and the fix has been implemented. Thank you for helping us improve our platform."
    when 'closed'
      "Your issue has been closed. If you have any further concerns, please don't hesitate to contact our support team."
    when 'rejected'
      "After careful review, we've determined that this issue doesn't require immediate attention. If you believe this is an error, please contact our support team."
    else
      "Your issue status has been updated. Please check our issues page for the latest information."
    end
  end
end
