class BuyerDetailsUtility
  # Extract comprehensive buyer details from review data
  def self.extract_buyer_details(review)
    return nil unless review&.buyer

    buyer = review.buyer
    
    {
      # Basic Information
      id: buyer.id,
      email: buyer.email,
      full_name: buyer.fullname,
      username: buyer.username,
      phone: buyer.phone_number,
      
      # Location Information
      city: buyer.city,
      county: get_county_name(buyer.county_id),
      sub_county: get_sub_county_name(buyer.sub_county_id),
      zipcode: buyer.zipcode,
      location: buyer.location,
      
      # Demographics
      gender: buyer.gender,
      age_group: get_age_group_name(buyer.age_group_id),
      age_group_id: buyer.age_group_id,
      
      # Professional Information
      income_level: get_income_level(buyer.income_id),
      employment_status: get_employment_status(buyer.employment_id),
      education_level: get_education_level(buyer.education_id),
      sector: get_sector_name(buyer.sector_id),
      
      # Account Status
      account_created: buyer.created_at,
      last_updated: buyer.updated_at,
      is_blocked: buyer.blocked,
      is_deleted: buyer.deleted,
      
      # Profile
      profile_picture: buyer.profile_picture,
      cart_total_price: buyer.cart_total_price,
      
      # Review Context
      review_rating: review.rating,
      review_text: review.review,
      review_date: review.created_at,
      review_id: review.id
    }
  end

  # Get buyer details for all reviews of a specific ad
  def self.get_ad_reviewers_details(ad_id)
    reviews = Review.where(ad_id: ad_id).includes(:buyer)
    
    reviewers_details = reviews.map do |review|
      extract_buyer_details(review)
    end.compact

    {
      ad_id: ad_id,
      total_reviews: reviews.count,
      unique_reviewers: reviewers_details.map { |r| r[:id] }.uniq.count,
      reviewers: reviewers_details,
      summary: generate_reviewers_summary(reviewers_details)
    }
  end

  # Generate summary statistics about reviewers
  def self.generate_reviewers_summary(reviewers_details)
    return {} if reviewers_details.empty?

    {
      # Demographics Summary
      gender_distribution: reviewers_details.group_by { |r| r[:gender] }.transform_values(&:count),
      age_group_distribution: reviewers_details.group_by { |r| r[:age_group] }.transform_values(&:count),
      location_distribution: reviewers_details.group_by { |r| r[:county] }.transform_values(&:count),
      
      # Rating Summary
      average_rating: reviewers_details.map { |r| r[:review_rating] }.sum.to_f / reviewers_details.count,
      rating_distribution: reviewers_details.group_by { |r| r[:review_rating] }.transform_values(&:count),
      
      # Account Status
      active_accounts: reviewers_details.count { |r| !r[:is_deleted] },
      blocked_accounts: reviewers_details.count { |r| r[:is_blocked] },
      
      # Professional Summary
      employment_distribution: reviewers_details.group_by { |r| r[:employment_status] }.transform_values(&:count),
      education_distribution: reviewers_details.group_by { |r| r[:education_level] }.transform_values(&:count)
    }
  end

  # Helper methods for lookup tables
  private

  def self.get_county_name(county_id)
    return nil unless county_id
    County.find_by(id: county_id)&.name
  end

  def self.get_sub_county_name(sub_county_id)
    return nil unless sub_county_id
    SubCounty.find_by(id: sub_county_id)&.name
  end

  def self.get_age_group_name(age_group_id)
    return nil unless age_group_id
    AgeGroup.find_by(id: age_group_id)&.name
  end

  def self.get_income_level(income_id)
    return nil unless income_id
    Income.find_by(id: income_id)&.name rescue nil
  end

  def self.get_employment_status(employment_id)
    return nil unless employment_id
    Employment.find_by(id: employment_id)&.name rescue nil
  end

  def self.get_education_level(education_id)
    return nil unless education_id
    Education.find_by(id: education_id)&.name rescue nil
  end

  def self.get_sector_name(sector_id)
    return nil unless sector_id
    Sector.find_by(id: sector_id)&.name rescue nil
  end
end
