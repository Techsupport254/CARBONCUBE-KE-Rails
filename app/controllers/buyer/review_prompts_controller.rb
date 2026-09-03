# frozen_string_literal: true

class Buyer::ReviewPromptsController < ApplicationController
  before_action :authenticate_user
  before_action :ensure_buyer_or_seller
  before_action :set_review_prompt, only: [:dismiss]

  def index
    prompts = current_user.review_prompts
      .not_dismissed_or_completed
      .where('scheduled_at <= ?', Time.current)
      .where(status: %w[pending sent])
      .includes(ad: :seller)
      .order(scheduled_at: :asc)
      .limit(50)

    render json: {
      prompts: prompts.map { |p| review_prompt_json(p) }
    }
  end

  def dismiss
    @review_prompt.mark_dismissed!
    head :no_content
  end

  private

  def ensure_buyer_or_seller
    return if current_user.is_a?(Buyer) || current_user.is_a?(Seller)

    render json: { error: 'Only buyers or sellers can access review prompts' }, status: :forbidden
  end

  def set_review_prompt
    @review_prompt = current_user.review_prompts.find(params[:id])
  end

  def review_prompt_json(prompt)
    ad = prompt.ad
    {
      id: prompt.id,
      ad_id: ad.id,
      ad_title: ad.title,
      ad_slug: Ad.slugify(ad.title),
      seller_name: ad.seller&.enterprise_name || ad.seller&.fullname,
      seller_enterprise_name: ad.seller&.enterprise_name,
      seller_email: ad.seller&.email,
      seller_profile_picture: ad.seller&.profile_picture,
      image_url: ad.media&.first,
      review_url: MarketingMailer.review_url_for(ad),
      scheduled_at: prompt.scheduled_at,
      status: prompt.status,
      reminders_count: prompt.reminders_count
    }
  end
end
