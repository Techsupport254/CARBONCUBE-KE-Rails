class CallSummaryMailer < ApplicationMailer
  default from: "Carbon Cube Kenya <#{ENV['BREVO_EMAIL']}>"
  layout false

  def call_summary_email
    customer_name = params[:customer_name]
    agent_name = params[:agent_name]
    call_type = params[:call_type]
    duration = params[:duration]
    call_reason = params[:call_reason]
    agent_notes = params[:agent_notes]
    rating_link = params[:rating_link]
    customer_email = params[:customer_email]

    timestamp = Time.current.strftime('%Y%m%d%H%M')
    subject = "Call Summary - #{timestamp}"

    mail(
      to: customer_email,
      subject: subject,
      react: {
        customer_name: customer_name,
        agent_name: agent_name,
        call_type: call_type,
        duration: duration,
        call_reason: call_reason,
        agent_notes: agent_notes,
        rating_link: rating_link,
        customer_email: customer_email
      }
    )
  end
end
