class AdminReportsMailer < ApplicationMailer
  default from: "Carbon Cube Kenya <#{ENV['BREVO_EMAIL']}>"

  def weekly_seller_checkpoint(admin_email, csv_content, pdf_content, seller_count)
    @seller_count = seller_count
    
    date_str = Date.today.to_s
    attachments["sellers_checkpoint_#{date_str}.csv"] = { mime_type: 'text/csv', content: csv_content }
    attachments["sellers_checkpoint_#{date_str}.pdf"] = { mime_type: 'application/pdf', content: pdf_content }
    
    mail(to: admin_email, subject: "Weekly Seller Checkpoint: #{date_str}")
  end
end
