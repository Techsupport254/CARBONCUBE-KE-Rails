# frozen_string_literal: true

class WhatsappAiPrefillService
  # Analyze user input to extract brand, model, and suggest improvements
  def self.analyze_input(title, category = nil)
    return { brand: nil, model: nil, suggested_title: nil, confidence: 0 } if title.blank?
    
    normalized_title = title.to_s.strip
    category_name = category&.name
    
    # Try to find matching device in catalog
    device_match = nil
    if category_name
      device_match = DeviceCatalogService.search(normalized_title, category_name).first
    end
    
    # Fallback to phones if no category specified
    device_match ||= DeviceCatalogService.search(normalized_title, 'phones').first
    
    if device_match
      {
        brand: device_match['brand'],
        model: device_match['title'],
        suggested_title: device_match['title'],
        confidence: calculate_confidence(normalized_title, device_match['title'])
      }
    else
      # Try to extract brand from title using common brands
      extracted_brand = extract_brand_from_title(normalized_title)
      {
        brand: extracted_brand,
        model: normalized_title,
        suggested_title: normalized_title,
        confidence: extracted_brand ? 0.5 : 0.3
      }
    end
  rescue => e
    Rails.logger.error "WhatsappAiPrefillService: Error analyzing input - #{e.message}"
    { brand: nil, model: nil, suggested_title: nil, confidence: 0 }
  end
  
  # Suggest category based on title and description
  def self.suggest_category(title, description = nil)
    return { category_id: nil, category_name: nil, confidence: 0 } if title.blank?
    
    combined_text = "#{title} #{description}".downcase
    
    # Category keywords mapping
    category_keywords = {
      'Computers Phones and Accessories' => %w[phone mobile laptop tablet computer ipad iphone samsung galaxy macbook dell hp lenovo android ios],
      'Automotive' => %w[car tyre tire battery oil engine wheel brake motor vehicle toyota honda bmw],
      'Filtration' => %w[filter water air oil fuel],
      'Hardware Tools' => %w[tool drill hammer screw wrench saw hardware electrical plumbing],
      'Equipment Leasing' => %w[equipment excavator bulldozer crane leasing machine construction]
    }
    
    best_match = nil
    best_score = 0
    
    category_keywords.each do |category_name, keywords|
      score = keywords.count { |keyword| combined_text.include?(keyword) }
      if score > best_score
        best_score = score
        best_match = category_name
      end
    end
    
    if best_match && best_score > 0
      category = Category.find_by('LOWER(name) = ?', best_match.downcase)
      if category
        confidence = [best_score * 0.2, 0.9].min
        return { category_id: category.id, category_name: category.name, confidence: confidence }
      end
    end
    
    { category_id: nil, category_name: nil, confidence: 0 }
  rescue => e
    Rails.logger.error "WhatsappAiPrefillService: Error suggesting category - #{e.message}"
    { category_id: nil, category_name: nil, confidence: 0 }
  end
  
  # Get price suggestions from similar products
  def self.get_price_suggestions(title, category_id = nil)
    return { min: nil, max: nil, median: nil, recommended: nil, count: 0 } if title.blank?
    
    normalized_title = title.to_s.downcase.strip
    tokens = normalized_title.split(/\s+/).reject(&:blank?)
    
    scope = Ad.active.from_active_sellers.where(flagged: false)
    scope = scope.where(category_id: category_id) if category_id.present?
    
    # Search for similar products
    similar_ads = scope.where(
      "LOWER(ads.title) LIKE :q OR LOWER(COALESCE(ads.brand, '')) LIKE :q",
      q: "%#{tokens.first}%"
    ).limit(50)
    
    prices = similar_ads.map(&:price).select { |p| p.present? && p > 0 }.sort
    
    return { min: nil, max: nil, median: nil, recommended: nil, count: 0 } if prices.empty?
    
    middle = prices.length / 2
    median = if prices.length.odd?
      prices[middle]
    else
      (prices[middle - 1] + prices[middle]) / 2.0
    end
    
    {
      min: prices.first.round(2),
      max: prices.last.round(2),
      median: median.round(2),
      recommended: median.round(2),
      count: prices.length
    }
  rescue => e
    Rails.logger.error "WhatsAppAIPrefillService: Error getting price suggestions - #{e.message}"
    { min: nil, max: nil, median: nil, recommended: nil, count: 0 }
  end
  
  # Fetch specifications for phones/tablets
  def self.fetch_specifications(title, category_id = nil)
    return {} if title.blank?
    
    category = Category.find_by(id: category_id)
    category_name = category&.name
    subcategory = category&.subcategories&.first
    
    # Check if this is a phone/tablet category
    is_phone_device = category_name&.downcase&.include?('phone') || 
                     category_name&.downcase&.include?('computer') ||
                     subcategory&.name&.downcase&.include?('phone') ||
                     subcategory&.name&.downcase&.include?('tablet') ||
                     subcategory&.name&.downcase&.include?('ipad')
    
    return {} unless is_phone_device
    
    # Try DeviceCatalogService first
    device_specs = DeviceCatalogService.search(title, subcategory&.name).first
    if device_specs && device_specs['specifications']
      return device_specs['specifications']
    end
    
    # Fallback to GSM Arena
    gsm_specs = GsmArenaService.fetch_device_specs(title)
    if gsm_specs && gsm_specs[:specifications]
      return gsm_specs[:specifications]
    end
    
    {}
  rescue => e
    Rails.logger.error "WhatsAppAIPrefillService: Error fetching specifications - #{e.message}"
    {}
  end
  
  # Generate intelligent description
  def self.generate_description(title, category, specifications = {})
    return "Please provide a description for this product." if title.blank?
    
    category_name = category&.name || 'Product'
    subcategory_name = category&.subcategories&.first&.name || 'General'
    
    # Build description with specifications if available
    if specifications && specifications.any?
      spec_lines = specifications.map { |key, value| "- #{key}: #{value}" }.join("\n")
      "### #{title}\n\nQuality #{subcategory_name.downcase} from #{category_name.downcase}.\n\n**Specifications:**\n#{spec_lines}\n\n- Well-maintained and in excellent condition\n- Suitable for buyers seeking value and reliability\n- Contact seller for availability and delivery options"
    else
      # Use category-aware template
      strategy = determine_strategy(category_name, subcategory_name)
      build_template_description(title, category_name, subcategory_name, strategy)
    end
  rescue => e
    Rails.logger.error "WhatsAppAIPrefillService: Error generating description - #{e.message}"
    "Quality product available. Contact seller for more details."
  end
  
  private
  
  def self.calculate_confidence(user_title, catalog_title)
    user_normalized = user_title.downcase
    catalog_normalized = catalog_title.downcase
    
    if user_normalized == catalog_normalized
      1.0
    elsif catalog_normalized.include?(user_normalized) || user_normalized.include?(catalog_normalized)
      0.8
    else
      # Check word overlap
      user_words = user_normalized.split(/\s+/)
      catalog_words = catalog_normalized.split(/\s+/)
      overlap = (user_words & catalog_words).length.to_f / [user_words.length, catalog_words.length].max
      [overlap, 0.6].max
    end
  end
  
  def self.extract_brand_from_title(title)
    common_brands = %w[samsung apple iphone xiaomi huawei oppo vivo tecno infinix nokia lg sony htc motorola lenovo dell hp asus acer toshiba msi macbook toyota honda bmw mercedes audi ford nissan mazda volkswagen]
    
    title_lower = title.downcase
    common_brands.find { |brand| title_lower.include?(brand) }&.capitalize
  end
  
  def self.determine_strategy(category_name, subcategory_name)
    text = [category_name, subcategory_name].compact.join(' ').downcase
    return 'phones_computers' if text.match?(/phone|mobile|laptop|computer|tablet|ipad/i)
    return 'automotive' if text.match?(/automotive|tyre|battery|spare|lubricant/i)
    return 'filtration' if text.match?(/filter|filtration/i)
    return 'hardware_tools' if text.match?(/hardware|tool|electrical|plumbing|safety/i)
    return 'equipment_leasing' if text.match?(/equipment|leasing|earth moving|drilling|lifting|concrete|compacting/i)
    'general'
  end
  
  def self.build_template_description(title, category_name, subcategory_name, strategy)
    category_label = category_name.presence || 'Product'
    subcategory_label = subcategory_name.presence || 'General'
    
    opening = case strategy
    when 'phones_computers'
      "### #{title} - #{subcategory_label}\n\nReliable #{subcategory_label.downcase} from #{category_label.downcase}, suitable for daily use, business, and long-term performance."
    when 'automotive'
      "### #{title} - #{subcategory_label}\n\nQuality #{subcategory_label.downcase} designed for dependable performance in demanding automotive use."
    when 'filtration'
      "### #{title} - #{subcategory_label}\n\nHigh-quality #{subcategory_label.downcase} built for efficient filtration and long service life."
    when 'hardware_tools'
      "### #{title} - #{subcategory_label}\n\nDurable #{subcategory_label.downcase} suitable for workshop, site, and professional use."
    when 'equipment_leasing'
      "### #{title} - #{subcategory_label}\n\nWell-maintained #{subcategory_label.downcase} available for project-based and long-term operational needs."
    else
      "### #{title} - #{subcategory_label}\n\nQuality #{subcategory_label.downcase} in the #{category_label.downcase} segment."
    end
    
    "#{opening}\n\n- Key features and condition details available on request.\n- Suitable for buyers seeking value, reliability, and verified seller support.\n- Contact seller for delivery options, warranty terms, and availability."
  end
end
