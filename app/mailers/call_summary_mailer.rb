class CallSummaryMailer < ApplicationMailer
  default from: "Carbon Cube Support <#{ENV['BREVO_EMAIL']}>"
  layout false

  def call_summary_email
    @customer_name = params[:customer_name]
    @agent_name = params[:agent_name]
    @call_type = params[:call_type]
    @duration = params[:duration]
    @call_reason = params[:call_reason]
    @agent_notes = params[:agent_notes]
    @rating_link = params[:rating_link]
    @customer_email = params[:customer_email]

    Rails.logger.info "=== CALL SUMMARY EMAIL START ==="
    Rails.logger.info "Customer: #{@customer_name}"
    Rails.logger.info "Customer Email: #{@customer_email}"
    Rails.logger.info "Agent: #{@agent_name}"
    Rails.logger.info "Rating Link: #{@rating_link}"

    # Generate unique subject with timestamp
    timestamp = Time.current.strftime('%Y%m%d%H%M')
    subject = "Call Summary - #{timestamp}"

    mail(
      to: @customer_email,
      subject: subject
    ) do |format|
      format.html { render 'call_summary_email' }
    end

    # Force new conversation
    mail['X-Threading'] = 'false'
    mail['X-Conversation-ID'] = SecureRandom.uuid

    Rails.logger.info "=== CALL SUMMARY EMAIL END ==="

    mail
  end
end
