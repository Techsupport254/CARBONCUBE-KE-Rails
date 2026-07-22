class ReviewMailer < ApplicationMailer
  default from: "Carbon Cube Kenya <#{ENV['BREVO_EMAIL']}>"

  def review_posted_notification
    review = params[:review]
    ad = review.ad
    seller = ad.seller
    buyer = review.buyer

    return unless seller&.email

    review_url = "https://carboncube-ke.com/ads/#{Ad.slugify(ad.title)}/review?id=#{ad.id}"

    mail(
      to: seller.email,
      subject: "New Review on your product: #{ad.title.truncate(40)}",
      react: {
        seller_name: seller.fullname || seller.enterprise_name,
        buyer_name: buyer&.username || buyer&.email&.split('@')&.first || 'A buyer',
        ad_title: ad.title,
        rating: review.rating || 5,
        review_content: review.content,
        review_url: review_url
      }
    )
  end

  def reply_posted_notification
    review = params[:review]
    ad = review.ad
    seller = ad.seller
    buyer = review.buyer

    return unless buyer&.email

    review_url = "https://carboncube-ke.com/ads/#{Ad.slugify(ad.title)}/review?id=#{ad.id}"

    mail(
      to: buyer.email,
      subject: "The seller replied to your review on #{ad.title.truncate(40)}",
      react: {
        buyer_name: buyer.username || buyer.email.split('@').first,
        seller_name: seller.fullname || seller.enterprise_name,
        ad_title: ad.title,
        seller_reply: review.seller_reply,
        review_url: review_url
      }
    )
  end
end
