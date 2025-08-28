#lib/tasks/document_expiry.rake
namespace :documents do
  desc "Send document expiry reminders"
  task send_reminders: :environment do
    today = Date.today

    Seller.where.not(document_expiry_date: nil).find_each do |seller|
      expiry = seller.document_expiry_date

      days_until_expiry = (expiry - today).to_i
      days_since_expiry = (today - expiry).to_i

      # 1-month reminder
      if days_until_expiry.between?(29, 31)
        SellerMailer.document_expiry_reminder(seller).deliver_later
        Rails.logger.info "Sent 1-month expiry reminder to #{seller.email}"
      end

      # 3-month after expiry reminder
      if days_since_expiry.between?(89, 91)
        SellerMailer.document_update_reminder(seller).deliver_later
        Rails.logger.info "Sent 3-month update reminder to #{seller.email}"
      end
    end
  end
end


# lib/tasks/document_expiry.rake
# namespace :documents do
#   desc "Test document expiry email"
#   task send_reminders: :environment do
#     Seller.where.not(document_expiry_date: nil).find_each do |seller|
#       SellerMailer.document_update_reminder(seller).deliver_now
#       Rails.logger.info "Test email sent to #{seller.email}"
#     end
#   end
# end
