# frozen_string_literal: true

class WhatsappAiPrefillService
  # Analyze user input to extract brand, model, and suggest improvements
  def self.analyze_input(title, category = nil)
    return { brand: nil, model: nil, suggested_title: nil, confidence: 0 } if title.blank?
    
    normalized_title = title.to_s.strip
    category_name = category&.name
    
    # Try to find matching device in catalog
    device_match = nil
    if category
      device_match = DeviceCatalogService.search(normalized_title, category.subcategories&.first&.name, category_name).first
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
      'Computers, Phones and Accessories' => %w[phone mobile laptop tablet computer ipad iphone samsung galaxy macbook dell hp lenovo android ios smartphone smartwatch watch keyboard mouse monitor webcam router modem networking storage hard drive ssd ram processor graphics card motherboard peripheral cooling],
      'Automotive Parts & Accessories' => %w[car tyre tire battery oil engine wheel brake motor vehicle toyota honda bmw mercedes nissan mazda subaru isuzu rims alloy steel lubricant gear synthetic spare parts accessories shocks suspension spark plug],
      'Filtration' => %w[filter water air oil fuel filtration hvac engine diesel hydraulic industrial purifier],
      'Hardware' => %w[tool drill hammer screw wrench saw hardware electrical plumbing generator welding cable pipe fitting cement sand construction building safety boots helmet gloves protective],
      'Services' => %w[service repair maintenance installation cleaning electrician plumber plumbing welder welding mason masonry painter painting carpenter carpentry appliance electronics specialist borehole drilling mechanic mechanics equipment leasing rental hire technician emergency],
      'TVs & Home Entertainment' => %w[tv television monitor display sound audio speaker smart android google led lcd oled qled 4k uhd hd samsung lg hisense tcl skyworth vitron sony soundbar home theater surround streaming fire stick chromecast apple decoder dstv gotv zuku startimes projector screen mount stand hdmi antenna satellite remote accessories],
      'Electronics and Accessories' => %w[printer copier scanner pos shredder projector office machine hp canon epson brother kyocera laser inkjet thermal barcode receipt cash register terminal toner cartridge document photocopy],
      'Agriculture' => %w[farm tractor irrigation tiller harvester plough seeder hoe panga slasher sprinkler machete fork shovel water pump pipe tank drip agriculture agricultural machinery equipment implement parts accessories]
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
    Rails.logger.error "WhatsappAiPrefillService: Error getting price suggestions - #{e.message}"
    { min: nil, max: nil, median: nil, recommended: nil, count: 0 }
  end
  
  # Fetch specifications for any product category
  def self.fetch_specifications(title, category_id = nil)
    return {} if title.blank?
    
    category = Category.find_by(id: category_id)
    category_name = category&.name
    subcategory = category&.subcategories&.first
    
    # Try DeviceCatalogService for all categories (it maps subcategories to catalog files)
    device_specs = DeviceCatalogService.search(title, subcategory&.name, category&.name).first
    if device_specs && device_specs['specifications']
      return device_specs['specifications']
    end
    
    # Fallback to GSM Arena only for phone/tablet-like devices
    is_phone_device = category_name&.downcase&.include?('phone') || 
                     category_name&.downcase&.include?('computer') ||
                     subcategory&.name&.downcase&.include?('phone') ||
                     subcategory&.name&.downcase&.include?('tablet') ||
                     subcategory&.name&.downcase&.include?('ipad')
    
    if is_phone_device
      gsm_specs = GsmArenaService.fetch_device_specs(title)
      if gsm_specs && gsm_specs[:specifications]
        return gsm_specs[:specifications]
      end
    end
    
    {}
  rescue => e
    Rails.logger.error "WhatsappAiPrefillService: Error fetching specifications - #{e.message}"
    {}
  end
  
  # Generate an SEO-friendly product/service description
  def self.generate_description(title, category, specifications = {})
    return "Please provide a description for this product." if title.blank?
    
    category_name = category&.name || 'Product'
    subcategory_name = category&.subcategories&.first&.name || 'General'
    
    # Extract pricing/negotiable hints if present
    pricing_model = specifications['Pricing Model']
    pricing_unit  = specifications['Pricing Unit']
    max_price     = specifications['Max Price']
    negotiable    = specifications['Negotiable'] || specifications['negotiable']
    
    seo_keywords = [title, category_name, subcategory_name, 'Kenya'].compact.join(', ')
    
    if specifications && specifications.any?
      spec_lines = specifications.reject { |k, _| %w[Pricing Model Pricing Unit Max Price Negotiable negotiable].include?(k) }
                                 .map { |key, value| "- #{key}: #{value}" }
                                 .join("\n")
      
      price_line = ""
      if pricing_model.present?
        price_line += "\n**Pricing:** #{pricing_model}"
        price_line += " #{pricing_unit}" if pricing_unit.present?
        price_line += " (max Ksh #{max_price})" if max_price.present?
        price_line += "."
      end
      price_line += "\n**Negotiable:** #{negotiable.to_s.downcase == 'yes' ? 'Yes' : 'Inquire with seller'}" if negotiable.present?
      
      "### #{title}\n\nBuy #{title} in Kenya. Quality #{subcategory_name.downcase} under #{category_name.downcase} category.#{price_line}\n\n**Specifications:**\n#{spec_lines}\n\n- #{category_name} #{subcategory_name} in excellent condition\n- Great value, reliable performance, and verified seller support\n- Contact seller for availability, delivery options, and the best price\n\n**Search keywords:** #{seo_keywords}"
    else
      strategy = determine_strategy(category_name, subcategory_name)
      build_template_description(title, category_name, subcategory_name, strategy)
    end
  rescue => e
    Rails.logger.error "WhatsappAiPrefillService: Error generating description - #{e.message}"
    "#{title} available in Kenya. Contact seller for more details and pricing."
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
    return 'services' if text.match?(/service|repair|mechanic|electrician|plumber|welder|mason|painter|carpenter|specialist/i)
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
      "### #{title} - #{subcategory_label}\n\nWell-maintained #{subcategory_label.downcase} available for project-based and long-term operational needs in Kenya."
    when 'services'
      "### #{title} - #{subcategory_label}\n\nProfessional #{subcategory_label.downcase} services in Kenya. Flexible pricing, reliable support, and quality workmanship for your needs."
    else
      "### #{title} - #{subcategory_label}\n\nQuality #{subcategory_label.downcase} in the #{category_label.downcase} segment, available in Kenya."
    end
    
    "#{opening}\n\n- Key features and condition details available on request.\n- Suitable for buyers seeking value, reliability, and verified seller support.\n- Contact seller for delivery options, warranty terms, and availability."
  end
end
