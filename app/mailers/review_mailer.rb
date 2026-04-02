class ReviewMailer < ApplicationMailer
  default from: "Carbon Cube Kenya <#{ENV['BREVO_EMAIL']}>"

  def review_posted_notification
    @review = params[:review]
    @ad = @review.ad
    @seller = @ad.seller
    @buyer = @review.buyer

    return unless @seller&.email

    mail(
      to: @seller.email,
      subject: "New Review on your product: #{@ad.title.truncate(40)}"
    )
  end

  def reply_posted_notification
    @review = params[:review]
    @ad = @review.ad
    @seller = @ad.seller
    @buyer = @review.buyer

    return unless @buyer&.email

    mail(
      to: @buyer.email,
      subject: "The seller replied to your review on #{@ad.title.truncate(40)}"
    )
  end
end
