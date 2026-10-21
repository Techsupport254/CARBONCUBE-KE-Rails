# frozen_string_literal: true

# Cold outreach to researched businesses that are not on the platform yet.
# Renders the same branded template as the sales team's manual outreach.
class ProspectMailer < ApplicationMailer
  PLAY_STORE_URL = 'https://play.google.com/store/apps/details?id=com.carbonmobile'

  def cold_outreach
    @business_name = params[:business_name].presence || 'there'
    @area = params[:area]
    @subcategory = params[:subcategory]
    @category = params[:category]
    @sender_name = params[:sender_name].presence || 'Vannessa'
    @play_store_url = PLAY_STORE_URL
    @personalization_line = params[:personalization_line].presence || default_personalization

    mail(
      to: params[:to],
      subject: "#{@business_name} on Carbon Cube — free Premium until 2027"
    )
  end

  private

  def default_personalization
    case @category.to_s.downcase
    when /automotive/
      "Auto parts is one of our busiest categories#{in_area}, and your shop would be a great fit."
    when /computer|phone/
      "Phones and electronics are our biggest category#{in_area} — your shop fits perfectly."
    when /services/
      "Buyers are actively looking for trusted #{@subcategory.to_s.downcase.presence || 'service'} providers#{in_area}."
    when /agric/
      "Farmers and agro-dealers#{in_area} are a fast-growing segment on the platform — we'd love to have you early."
    else
      "#{@subcategory.to_s.downcase.presence || 'Your category'} sellers#{in_area} are in demand on the platform."
    end
  end

  def in_area
    @area.present? ? " around #{@area}" : ' in your area'
  end
end
