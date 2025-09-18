class SellerMailer < ApplicationMailer
  default from: 'noreply@carboncube-ke.com'

  def document_expiry_reminder(seller)
    @seller = seller
    mail(to: @seller.email, subject: "Document Expiry Reminder")
  end

  def document_update_reminder(seller)
    @seller = seller
    mail(to: @seller.email, subject: "Please Update Your Expired Document")
  end
end
