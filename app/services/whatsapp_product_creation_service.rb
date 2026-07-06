# frozen_string_literal: true

require_relative 'whats_app_ai_prefill_service'

class WhatsAppProductCreationService
  COMMAND_START = 'ADD'
  COMMAND_CANCEL = 'CANCEL'
  COMMAND_HELP = 'HELP'
  
  def self.process_message(seller, phone_number, message_content, media_urls = [])
    message = message_content.to_s.strip.upcase
    
    # Check for commands
    if message == COMMAND_START
      return start_product_creation(seller, phone_number)
    elsif message == COMMAND_CANCEL
      return cancel_product_creation(seller, phone_number)
    elsif message == COMMAND_HELP
      return help_message
    end
    
    # Check if there's an active session
    session = WhatsappProductSession.active.for_phone(phone_number).where(seller_id: seller.id).first
    
    unless session
      return {
        success: true,
        response: help_message,
        should_respond: true
      }
    end
    
    # Process based on current step
    process_step(session, message_content, media_urls)
  end
  
  def self.start_product_creation(seller, phone_number)
    # Check if seller has active subscription
    seller_tier = seller.seller_tier
    unless seller_tier && seller_tier.tier
      return {
        success: false,
        response: "You don't have an active subscription tier. Please upgrade your account to post ads.",
        should_respond: true
      }
    end
    
    # Check ad limit
    ad_limit = seller_tier.tier.ads_limit || 0
    current_ads_count = seller.ads.count
    if current_ads_count >= ad_limit
      return {
        success: false,
        response: "You've reached your ad limit (#{ad_limit} ads). Please upgrade your tier to add more products.",
        should_respond: true
      }
    end
    
    # Create or reset session
    session = WhatsappProductSession.find_or_create_session(seller, phone_number)
    
    {
      success: true,
      response: welcome_message,
      should_respond: true
    }
  end
  
  def self.cancel_product_creation(seller, phone_number)
    session = WhatsappProductSession.active.for_phone(phone_number).where(seller_id: seller.id).first
    
    if session
      session.cancel!
      {
        success: true,
        response: "Product creation cancelled. Send 'ADD' to start again.",
        should_respond: true
      }
    else
      {
        success: true,
        response: "No active product creation session. Send 'ADD' to start adding a product.",
        should_respond: true
      }
    end
  end
  
  def self.process_step(session, message_content, media_urls)
    # Handle special commands for description enhancement
    if session.step == 3 && message_content.to_s.strip.upcase == 'ENHANCE'
      return handle_enhance_description(session)
    elsif session.step == 3 && message_content.to_s.strip.upcase == 'KEEP'
      return handle_keep_description(session)
    end
    
    case session.step
    when 1 # Title
      process_title_step(session, message_content)
    when 2 # Description
      process_description_step(session, message_content)
    when 3 # Price
      process_price_step(session, message_content)
    when 4 # Category
      process_category_step(session, message_content)
    when 5 # Brand
      process_brand_step(session, message_content)
    when 6 # Condition
      process_condition_step(session, message_content)
    when 7 # Images
      process_images_step(session, media_urls, message_content)
    when 8 # Confirm
      process_confirm_step(session, message_content)
    else
      session.cancel!
      {
        success: false,
        response: "Invalid step. Session cancelled. Send 'ADD' to start again.",
        should_respond: true
      }
    end
  end
  
  def self.process_title_step(session, message_content)
    title = message_content.strip
    
    if title.length < 10
      return {
        success: false,
        response: "Title is too short (minimum 10 characters). Please try again:",
        should_respond: true
      }
    end
    
    if title.length > 150
      return {
        success: false,
        response: "Title is too long (maximum 150 characters). Please try again:",
        should_respond: true
      }
    end
    
    # Use AI to analyze title and detect brand
    ai_analysis = WhatsappAiPrefillService.analyze_input(title)
    
    session.update_product_data('title', title)
    
    # Auto-detect brand if confidence is high
    if ai_analysis[:brand] && ai_analysis[:confidence] > 0.6
      session.update_product_data('brand', ai_analysis[:brand])
      session.update_product_data('ai_detected_brand', true)
    end
    
    session.advance_step!
    
    response = "✅ Title saved!"
    
    if ai_analysis[:brand] && ai_analysis[:confidence] > 0.6
      response += "\n\n🤖 AI detected brand: #{ai_analysis[:brand]}"
    end
    
    if ai_analysis[:suggested_title] && ai_analysis[:suggested_title] != title && ai_analysis[:confidence] > 0.7
      response += "\n\n💡 Suggested title: #{ai_analysis[:suggested_title]}"
      response += "\n(You can use this or keep your original title)"
    end
    
    response += "\n\nNow, please provide a description for your product (minimum 20 characters):"
    
    {
      success: true,
      response: response,
      should_respond: true
    }
  end
  
  def self.handle_enhance_description(session)
    ai_description = session.get_product_data('ai_description')
    
    if ai_description
      session.update_product_data('description', ai_description)
      session.update_product_data('ai_enhanced', true)
      
      {
        success: true,
        response: "✅ Description enhanced with AI!\n\nNow, please provide the price in KES (e.g., 5000):",
        should_respond: true
      }
    else
      {
        success: false,
        response: "AI description not available. Please provide the price in KES (e.g., 5000):",
        should_respond: true
      }
    end
  end
  
  def self.handle_keep_description(session)
    {
      success: true,
      response: "✅ Keeping your original description.\n\nNow, please provide the price in KES (e.g., 5000):",
      should_respond: true
    }
  end
  
  def self.process_description_step(session, message_content)
    description = message_content.strip
    
    if description.length < 20
      return {
        success: false,
        response: "Description is too short (minimum 20 characters). Please try again:",
        should_respond: true
      }
    end
    
    if description.length > 5000
      return {
        success: false,
        response: "Description is too long (maximum 5000 characters). Please try again:",
        should_respond: true
      }
    end
    
    session.update_product_data('description', description)
    
    # Generate AI-enhanced description as optional suggestion
    title = session.get_product_data('title')
    category_id = session.get_product_data('category_id')
    specifications = session.get_product_data('specifications')
    
    if title && category_id
      category = Category.find_by(id: category_id)
      ai_description = WhatsappAiPrefillService.generate_description(title, category, specifications)
      session.update_product_data('ai_description', ai_description)
    end
    
    session.advance_step!
    
    response = "✅ Description saved!"
    
    if session.get_product_data('ai_description')
      response += "\n\n💡 AI can enhance your description with professional formatting and specifications."
      response += "\nReply 'ENHANCE' to use AI description or 'KEEP' to use your original."
    else
      response += "\n\nNow, please provide the price in KES (e.g., 5000):"
    end
    
    {
      success: true,
      response: response,
      should_respond: true
    }
  end
  
  def self.process_price_step(session, message_content)
    price = message_content.strip.gsub(/[^0-9.]/, '').to_f
    
    if price <= 0
      return {
        success: false,
        response: "Invalid price. Please enter a valid price in KES (e.g., 5000):",
        should_respond: true
      }
    end
    
    if price > 1000000
      return {
        success: false,
        response: "Price is too high (maximum 1,000,000 KES). Please try again:",
        should_respond: true
      }
    end
    
    session.update_product_data('price', price)
    
    # Get AI price suggestions
    title = session.get_product_data('title')
    category_id = session.get_product_data('category_id')
    price_suggestions = WhatsAppAIPrefillService.get_price_suggestions(title, category_id) if title
    
    session.advance_step!
    
    # Get available categories
    categories = Category.all.limit(10).pluck(:name)
    category_list = categories.map.with_index(1) { |cat, i| "#{i}. #{cat}" }.join("\n")
    
    response = "✅ Price saved: #{price} KES"
    
    if price_suggestions[:count] > 0
      response += "\n\n💰 Market data for similar products (#{price_suggestions[:count]} found):"
      response += "\n- Price range: #{price_suggestions[:min]} - #{price_suggestions[:max]} KES"
      response += "\n- Average price: #{price_suggestions[:median]} KES"
      
      if price_suggestions[:recommended]
        response += "\n- Recommended: #{price_suggestions[:recommended]} KES"
      end
      
      # Warn if price is significantly different
      if price < price_suggestions[:min] * 0.7
        response += "\n⚠️ Your price is below market average. Consider adjusting."
      elsif price > price_suggestions[:max] * 1.3
        response += "\n⚠️ Your price is above market average. Ensure competitive pricing."
      end
    end
    
    response += "\n\nNow, please select a category by number:\n#{category_list}\n\nOr type the category name:"
    
    {
      success: true,
      response: response,
      should_respond: true
    }
  end
  
  def self.process_category_step(session, message_content)
    input = message_content.strip
    
    # Try to find by number first
    if input.match?(/^\d+$/)
      category_index = input.to_i - 1
      categories = Category.all.limit(10)
      category = categories.offset(category_index).first
      
      if category
        session.update_product_data('category_id', category.id)
        session.advance_step!
        
        return {
          success: true,
          response: "✅ Category saved: #{category.name}\n\nNow, please provide the brand (e.g., Samsung, Apple, Toyota):",
          should_respond: true
        }
      end
    end
    
    # Try to find by name
    category = Category.where('LOWER(name) LIKE ?', "%#{input.downcase}%").first
    
    if category
      session.update_product_data('category_id', category.id)
      session.advance_step!
      
      {
        success: true,
        response: "✅ Category saved: #{category.name}\n\nNow, please provide the brand (e.g., Samsung, Apple, Toyota):",
        should_respond: true
      }
    else
      # Use AI to suggest category based on title
      title = session.get_product_data('title')
      ai_suggestion = WhatsAppAIPrefillService.suggest_category(title) if title
      
      categories = Category.all.limit(10).pluck(:name)
      category_list = categories.map.with_index(1) { |cat, i| "#{i}. #{cat}" }.join("\n")
      
      response = "Category not found. Please select from the list:\n#{category_list}\n\nOr type the category name:"
      
      if ai_suggestion[:category_id] && ai_suggestion[:confidence] > 0.5
        response += "\n\n🤖 AI suggests: #{ai_suggestion[:category_name]}"
        response += "\nReply '#{ai_suggestion[:category_name]}' to use this suggestion"
      end
      
      {
        success: false,
        response: response,
        should_respond: true
      }
    end
  end
  
  def self.process_brand_step(session, message_content)
    brand = message_content.strip
    
    if brand.length < 2
      return {
        success: false,
        response: "Brand is too short. Please try again:",
        should_respond: true
      }
    end
    
    session.update_product_data('brand', brand)
    
    # Try to fetch specifications if this is a phone/tablet
    title = session.get_product_data('title')
    category_id = session.get_product_data('category_id')
    if title && category_id
      specs = WhatsAppAIPrefillService.fetch_specifications(title, category_id)
      if specs && specs.any?
        session.update_product_data('specifications', specs)
      end
    end
    
    session.advance_step!
    
    conditions = Ad.conditions.keys.map { |c| c.to_s.humanize }
    condition_list = conditions.map.with_index(1) { |cond, i| "#{i}. #{cond}" }.join("\n")
    
    response = "✅ Brand saved: #{brand}"
    
    # Notify if specs were fetched
    if session.get_product_data('specifications')
      response += "\n\n🤖 AI fetched product specifications automatically!"
    end
    
    response += "\n\nNow, please select the condition by number:\n#{condition_list}"
    
    {
      success: true,
      response: response,
      should_respond: true
    }
  end
  
  def self.process_condition_step(session, message_content)
    input = message_content.strip
    conditions = Ad.conditions.keys
    
    if input.match?(/^\d+$/)
      condition_index = input.to_i - 1
      condition = conditions[condition_index]
      
      if condition
        session.update_product_data('condition', condition)
        session.advance_step!
        
        return {
          success: true,
          response: "✅ Condition saved: #{condition.humanize}\n\nNow, please send product images (up to 5 images). Send 'SKIP' if you don't have images ready.",
          should_respond: true
        }
      end
    end
    
    # Try to match by name
    condition = conditions.find { |c| c.to_s.downcase.include?(input.downcase) }
    
    if condition
      session.update_product_data('condition', condition)
      session.advance_step!
      
      {
        success: true,
        response: "✅ Condition saved: #{condition.humanize}\n\nNow, please send product images (up to 5 images). Send 'SKIP' if you don't have images ready.",
        should_respond: true
      }
    else
      condition_list = conditions.map.with_index(1) { |cond, i| "#{i}. #{cond.to_s.humanize}" }.join("\n")
      
      {
        success: false,
        response: "Invalid condition. Please select from the list:\n#{condition_list}",
        should_respond: true
      }
    end
  end
  
  def self.process_images_step(session, media_urls, message_content = nil)
    if media_urls.any?
      existing_images = session.get_product_data('media') || []
      new_images = media_urls.first(5) # Max 5 images
      all_images = (existing_images + new_images).uniq.first(5)
      
      session.update_product_data('media', all_images)
      
      if all_images.length >= 3
        session.advance_step!
        return {
          success: true,
          response: "✅ Images saved (#{all_images.length} images)!\n\n#{product_summary(session)}\n\nReply 'CONFIRM' to create this product or 'CANCEL' to start over.",
          should_respond: true
        }
      else
        return {
          success: true,
          response: "✅ Image added (#{all_images.length}/5). Send more images or 'DONE' to continue.",
          should_respond: true
        }
      end
    elsif message_content && (message_content.to_s.strip.upcase == 'SKIP' || message_content.to_s.strip.upcase == 'DONE')
      session.advance_step!
      {
        success: true,
        response: "Images skipped.\n\n#{product_summary(session)}\n\nReply 'CONFIRM' to create this product or 'CANCEL' to start over.",
        should_respond: true
      }
    else
      {
        success: false,
        response: "Please send product images or type 'SKIP' to continue without images.",
        should_respond: true
      }
    end
  end
  
  def self.process_confirm_step(session, message_content)
    input = message_content.strip.upcase
    
    if input == 'CONFIRM'
      result = create_product(session)
      
      if result[:success]
        session.complete!
        
        # Generate product link with UTM parameters
        ad = result[:ad]
        product_link = ad.product_url_with_utm(source: 'whatsapp', medium: 'product_creation', campaign: 'whatsapp_ai')
        
        response = "🎉 Product created successfully!\n\n"
        response += "Your product is now live on CarbonCube.\n\n"
        response += "🔗 Product Link: #{product_link}\n\n"
        response += "You can view and manage it from your seller dashboard."
        
        {
          success: true,
          response: response,
          should_respond: true
        }
      else
        {
          success: false,
          response: "Failed to create product: #{result[:error]}\n\nReply 'RETRY' to try again or 'CANCEL' to start over.",
          should_respond: true
        }
      end
    elsif input == 'CANCEL'
      session.cancel!
      {
        success: true,
        response: "Product creation cancelled. Send 'ADD' to start again.",
        should_respond: true
      }
    else
      {
        success: false,
        response: "Please reply 'CONFIRM' to create this product or 'CANCEL' to start over.",
        should_respond: true
      }
    end
  end
  
  def self.create_product(session)
    product_data = session.product_data
    
    # Validate required fields
    required_fields = ['title', 'description', 'price', 'category_id', 'brand', 'condition']
    missing_fields = required_fields.select { |field| product_data[field].blank? }
    
    if missing_fields.any?
      return {
        success: false,
        error: "Missing required fields: #{missing_fields.join(', ')}"
      }
    end
    
    # Create the ad
    ad = session.seller.ads.build(
      title: product_data['title'],
      description: product_data['description'],
      price: product_data['price'],
      category_id: product_data['category_id'],
      brand: product_data['brand'],
      condition: product_data['condition'],
      media: product_data['media'] || [],
      is_added_by_sales: false
    )
    
    if ad.save
      {
        success: true,
        ad: ad
      }
    else
      {
        success: false,
        error: ad.errors.full_messages.join(', ')
      }
    end
  rescue => e
    Rails.logger.error "WhatsAppProductCreationService: Error creating product - #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    {
      success: false,
      error: "An error occurred while creating the product"
    }
  end
  
  def self.product_summary(session)
    data = session.product_data
    
    summary = "📦 *Product Summary*\n\n"
    summary += "*Title:* #{data['title']}\n"
    summary += "*Price:* #{data['price']} KES\n"
    summary += "*Brand:* #{data['brand']}\n"
    summary += "*Condition:* #{data['condition']&.humanize}\n"
    
    category = Category.find_by(id: data['category_id'])
    summary += "*Category:* #{category&.name || 'N/A'}\n"
    
    if data['media']&.any?
      summary += "*Images:* #{data['media'].length} image(s)\n"
    else
      summary += "*Images:* None\n"
    end
    
    summary
  end
  
  def self.welcome_message
    "🚀 *Let's add your product!*\n\nI'll guide you through creating a product listing step by step.\n\nStep 1/8: Please provide a title for your product (minimum 10 characters):\n\nSend 'CANCEL' at any time to stop."
  end
  
  def self.help_message
    "📱 *WhatsApp Product Creation Help*\n\nCommands:\n• ADD - Start adding a new product\n• CANCEL - Cancel current product creation\n• HELP - Show this help message\n\nThe process will guide you through:\n1. Product title\n2. Description\n3. Price\n4. Category\n5. Brand\n6. Condition\n7. Images\n8. Confirmation\n\nSend 'ADD' to get started!"
  end
end
