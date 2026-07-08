# frozen_string_literal: true

class ImageAnalysisService
  # Analyze image using Cloudinary AI to extract product information
  def self.analyze_image(image_url)
    return { success: false, error: "No image URL provided" } if image_url.blank?
    
    begin
      # Try to use Cloudinary's AI Content Analysis add-on
      cloudinary_response = Cloudinary::Api.resource(image_url, 
        analysis: true,
        analysis_type: 'coco_v2'
      )
      
      if cloudinary_response && cloudinary_response['analysis']
        analysis_data = cloudinary_response['analysis']
        
        # Extract relevant information from AI analysis
        {
          success: true,
          detected_objects: extract_objects(analysis_data),
          categories: extract_categories(analysis_data),
          confidence: calculate_confidence(analysis_data),
          condition: estimate_condition(analysis_data),
          raw_analysis: analysis_data
        }
      else
        # Fallback: Use basic image info without AI
        {
          success: true,
          detected_objects: [],
          categories: [],
          confidence: 0,
          condition: nil,
          raw_analysis: nil,
          note: "Cloudinary AI analysis not available, will use title-based analysis"
        }
      end
    rescue => e
      Rails.logger.error "ImageAnalysisService: Error analyzing image - #{e.message}"
      # Fallback to basic analysis if Cloudinary AI fails
      {
        success: true,
        detected_objects: [],
        categories: [],
        confidence: 0,
        condition: nil,
        raw_analysis: nil,
        note: "Cloudinary AI analysis failed, will use title-based analysis"
      }
    end
  end
  
  # Analyze multiple images and combine results
  def self.analyze_multiple_images(image_urls)
    return { success: false, error: "No image URLs provided" } if image_urls.blank?
    
    results = image_urls.map { |url| analyze_image(url) }
    successful_results = results.select { |r| r[:success] }
    
    if successful_results.empty?
      return { success: false, error: "Failed to analyze any images" }
    end
    
    # Combine results from multiple images
    combined_objects = successful_results.flat_map { |r| r[:detected_objects] }.uniq
    combined_categories = successful_results.flat_map { |r| r[:categories] }.uniq
    avg_confidence = successful_results.map { |r| r[:confidence] }.sum / successful_results.length.to_f
    
    # Determine most likely condition from all images
    conditions = successful_results.map { |r| r[:condition] }.compact
    most_likely_condition = conditions.group_by(&:itself).values.max_by(&:size)&.first
    
    {
      success: true,
      detected_objects: combined_objects,
      categories: combined_categories,
      confidence: avg_confidence,
      condition: most_likely_condition,
      image_count: image_urls.length,
      successfully_analyzed: successful_results.length
    }
  end
  
  # Map detected objects to product categories
  def self.suggest_category(detected_objects, title = nil)
    return { category_id: nil, category_name: nil, confidence: 0 } if detected_objects.blank?
    
    # Object to category mapping
    object_category_map = {
      'phone' => 'Computers, Phones and Accessories',
      'mobile phone' => 'Computers, Phones and Accessories',
      'smartphone' => 'Computers, Phones and Accessories',
      'laptop' => 'Computers, Phones and Accessories',
      'computer' => 'Computers, Phones and Accessories',
      'tablet' => 'Computers, Phones and Accessories',
      'ipad' => 'Computers, Phones and Accessories',
      'car' => 'Automotive Parts & Accessories',
      'automobile' => 'Automotive Parts & Accessories',
      'vehicle' => 'Automotive Parts & Accessories',
      'tire' => 'Automotive Parts & Accessories',
      'wheel' => 'Automotive Parts & Accessories',
      'furniture' => 'Hardware',
      'chair' => 'Hardware',
      'table' => 'Hardware',
      'sofa' => 'Hardware',
      'tv' => 'TVs & Home Entertainment',
      'television' => 'TVs & Home Entertainment',
      'camera' => 'Computers, Phones and Accessories',
      'watch' => 'Computers, Phones and Accessories'
    }
    
    # Find best matching category based on detected objects
    best_match = nil
    best_score = 0
    
    detected_objects.each do |object|
      object_lower = object.downcase
      object_category_map.each do |obj, category|
        if object_lower.include?(obj) || obj.include?(object_lower)
          best_match = category
          best_score = 0.8
        end
      end
    end
    
    # If title is provided, use it as fallback
    if !best_match && title.present?
      title_suggestion = WhatsappAiPrefillService.suggest_category(title)
      if title_suggestion[:confidence] > 0.5
        best_match = title_suggestion[:category_name]
        best_score = title_suggestion[:confidence]
      end
    end
    
    if best_match
      category = Category.find_by('LOWER(name) = ?', best_match.downcase)
      if category
        return { category_id: category.id, category_name: category.name, confidence: best_score }
      end
    end
    
    { category_id: nil, category_name: nil, confidence: 0 }
  end
  
  # Extract brand from detected objects and title
  def self.suggest_brand(detected_objects, title = nil)
    common_brands = %w[samsung apple iphone xiaomi huawei oppo vivo tecno infinix nokia lg sony htc motorola lenovo dell hp asus acer toshiba msi macbook toyota honda bmw mercedes audi ford nissan mazda volkswagen]
    
    # Check detected objects for brand names
    object_brand = detected_objects.find { |obj| common_brands.any? { |brand| obj.downcase.include?(brand) } }
    
    if object_brand
      brand = common_brands.find { |b| object_brand.downcase.include?(b) }&.capitalize
      return { brand: brand, confidence: 0.7 }
    end
    
    # Fallback to title analysis
    if title.present?
      title_brand = WhatsappAiPrefillService.analyze_input(title)[:brand]
      if title_brand
        return { brand: title_brand, confidence: 0.5 }
      end
    end
    
    { brand: nil, confidence: 0 }
  end
  
  private
  
  def self.extract_objects(analysis_data)
    return [] unless analysis_data['tags']
    
    # Extract object tags from Cloudinary analysis
    analysis_data['tags'].map { |tag| tag['tag'] }.compact.uniq
  end
  
  def self.extract_categories(analysis_data)
    return [] unless analysis_data['categories']
    
    # Extract category information
    analysis_data['categories'].map { |cat| cat['name'] }.compact.uniq
  end
  
  def self.calculate_confidence(analysis_data)
    return 0 unless analysis_data['tags']
    
    # Calculate average confidence from detected objects
    confidences = analysis_data['tags'].map { |tag| tag['confidence'] || 0 }
    return 0 if confidences.empty?
    
    confidences.sum / confidences.length.to_f
  end
  
  def self.estimate_condition(analysis_data)
    # Estimate condition based on image quality indicators
    # This is a simplified version - could be enhanced with more sophisticated analysis
    return nil unless analysis_data['quality']
    
    quality_score = analysis_data['quality']['score'] || 0
    
    if quality_score > 0.8
      'brand_new'
    elsif quality_score > 0.6
      'second_hand'
    elsif quality_score > 0.4
      'refurbished'
    else
      'second_hand'
    end
  rescue
    nil
  end
end
