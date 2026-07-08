# frozen_string_literal: true

class WhatsappProductCreationService
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
    
    # Create or reset session with image-first mode
    session = WhatsappProductSession.find_or_create_session(seller, phone_number)
    session.update(step: 1, status: 'pending') # Step 1: Image upload
    
    {
      success: true,
      response: welcome_message_image_first,
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
    # Handle special commands for editing
    if message_content.to_s.strip.upcase == 'EDIT'
      return handle_edit_mode(session)
    elsif message_content.to_s.strip.upcase == 'CONFIRM'
      return process_confirm_step(session, 'CONFIRM')
    elsif message_content.to_s.strip.upcase == 'CANCEL'
      return cancel_product_creation(session.seller, session.phone_number)
    end
    
    # Handle interactive button responses (format: "category_123" or "subcategory_456")
    if message_content.to_s.start_with?('category_') || message_content.to_s.start_with?('subcategory_')
      return handle_category_selection(session, message_content.to_s.strip)
    end
    
    # Handle text-based category selection (fallback)
    if session.step == 4 && message_content.to_s.strip.upcase == 'CATEGORY'
      return send_category_selection(session.phone_number)
    end
    
    case session.step
    when 1 # Image upload
      process_images_step(session, media_urls, message_content)
    when 2 # Title + AI analysis
      process_title_with_ai_step(session, message_content)
    when 3 # Confirm/Edit
      process_confirm_step(session, message_content)
    when 4 # Edit mode
      handle_edit_input(session, message_content)
    when 5 # Category selection (triggered when AI confidence is low)
      send_category_selection(session.phone_number)
      {
        success: true,
        response: nil,
        should_respond: false
      }
    else
      session.cancel!
      {
        success: false,
        response: "Invalid step. Session cancelled. Send 'ADD' to start again.",
        should_respond: true
      }
    end
  end
  
  def self.process_title_with_ai_step(session, message_content)
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
    
    # Save title
    session.update_product_data('title', title)
    
    # Get uploaded images
    media_urls = session.get_product_data('media') || []
    
    if media_urls.any?
      # Analyze images using AI
      image_analysis = ImageAnalysisService.analyze_multiple_images(media_urls)
      
      if image_analysis[:success]
        # Extract AI insights
        category_suggestion = ImageAnalysisService.suggest_category(image_analysis[:detected_objects], title)
        brand_suggestion = ImageAnalysisService.suggest_brand(image_analysis[:detected_objects], title)
        
        # Save AI-detected data
        session.update_product_data('category_id', category_suggestion[:category_id]) if category_suggestion[:category_id]
        session.update_product_data('brand', brand_suggestion[:brand]) if brand_suggestion[:brand]
        session.update_product_data('condition', image_analysis[:condition]) if image_analysis[:condition]
        session.update_product_data('ai_confidence', image_analysis[:confidence])
        session.update_product_data('detected_objects', image_analysis[:detected_objects])
        
        # Get price suggestion
        price_suggestion = WhatsappAiPrefillService.get_price_suggestions(title, category_suggestion[:category_id])
        session.update_product_data('suggested_price', price_suggestion[:recommended]) if price_suggestion[:recommended]
        
        # Generate AI description
        if category_suggestion[:category_id]
          category = Category.find_by(id: category_suggestion[:category_id])
          ai_description = WhatsappAiPrefillService.generate_description(title, category, {})
          session.update_product_data('ai_description', ai_description)
        end
        
        session.advance_step!
        
        # Build AI analysis response
        response = "✅ Title saved!\n\n🤖 Analyzing your images...\n\n"
        response += "I detected:\n"
        
        if image_analysis[:detected_objects].any?
          response += "📊 Objects: #{image_analysis[:detected_objects].first(3).join(', ')}\n"
        end
        
        if brand_suggestion[:brand]
          response += "🏷️ Brand: #{brand_suggestion[:brand]} (#{(brand_suggestion[:confidence] * 100).to_i}% confidence)\n"
        end
        
        if category_suggestion[:category_name]
          response += "📂 Category: #{category_suggestion[:category_name]} (#{(category_suggestion[:confidence] * 100).to_i}% confidence)\n"
        end
        
        if image_analysis[:condition]
          response += "✨ Condition: #{image_analysis[:condition].humanize}\n"
        end
        
        if price_suggestion[:recommended]
          response += "\n💰 Suggested price: KES #{price_suggestion[:recommended]} (based on similar items)\n"
        end
        
        # Trigger category selection if AI confidence is low
        if category_suggestion[:confidence] < 0.6
          response += "\n⚠️ AI category confidence is low. Please select correct category:"
          # Don't advance to confirm step, instead trigger category selection
          session.update(step: 5) # Category selection step
          return {
            success: true,
            response: response,
            should_respond: true,
            trigger_category_selection: true
          }
        end
        
        response += "\nReply CONFIRM to post or EDIT to change anything"
        
        {
          success: true,
          response: response,
          should_respond: true
        }
      else
        # Fallback to text-only analysis
        session.advance_step!
        
        response = "✅ Title saved!\n\nAI image analysis unavailable. Using title analysis instead.\n\n"
        response += "Reply CONFIRM to post or EDIT to change anything"
        
        {
          success: true,
          response: response,
          should_respond: true
        }
      end
    else
      # No images uploaded, use text-only analysis
      session.advance_step!
      
      response = "✅ Title saved!\n\nNo images uploaded. Using title analysis only.\n\n"
      response += "Reply CONFIRM to post or EDIT to change anything"
      
      {
        success: true,
        response: response,
        should_respond: true
      }
    end
  rescue => e
    Rails.logger.error "WhatsappProductCreationService: Error in process_title_with_ai_step - #{e.message}"
    {
      success: false,
      response: "Error analyzing product. Please try again.",
      should_respond: true
    }
  end
  
  def self.handle_edit_mode(session)
    product_data = session.product_data
    
    response = "✏️ *Edit Mode*\n\n"
    response += "Current details:\n"
    response += "*Title:* #{product_data['title']}\n"
    response += "*Brand:* #{product_data['brand'] || 'Not set'}\n"
    response += "*Condition:* #{product_data['condition']&.humanize || 'Not set'}\n"
    
    category = Category.find_by(id: product_data['category_id'])
    response += "*Category:* #{category&.name || 'Not set'}\n"
    
    if product_data['suggested_price']
      response += "*Suggested Price:* KES #{product_data['suggested_price']}\n"
    end
    
    response += "\nWhat would you like to edit?\n"
    response += "Reply with:\n"
    response += "• 'PRICE [amount]' - Set price\n"
    response += "• 'BRAND [name]' - Set brand\n"
    response += "• 'CONDITION [number]' - Set condition (1-5)\n"
    response += "• 'CATEGORY' - Change category\n"
    response += "• 'DONE' - Finish editing"
    
    session.update(step: 4) # Edit mode step
    
    {
      success: true,
      response: response,
      should_respond: true
    }
  end
  
  def self.send_category_selection(phone_number)
    categories = Category.all.limit(10)
    
    # Create interactive list for categories
    sections = [{
      title: "Select Category",
      rows: categories.map { |cat|
        {
          id: "category_#{cat.id}",
          title: cat.name,
          description: "Click to select"
        }
      }
    }]
    
    # Send interactive list message
    WhatsAppCloudService.send_interactive_list(
      phone_number,
      "Please select a category for your product:",
      "Choose Category",
      "Select Category",
      sections
    )
    
    {
      success: true,
      response: nil, # Interactive message sent separately
      should_respond: false,
      interactive: true
    }
  rescue => e
    Rails.logger.error "WhatsappProductCreationService: Error sending category selection - #{e.message}"
    {
      success: false,
      response: "Error loading categories. Please try again.",
      should_respond: true
    }
  end
  
  def self.send_subcategory_selection(phone_number, category_id)
    category = Category.find_by(id: category_id)
    return { success: false, response: "Category not found", should_respond: true } unless category
    
    subcategories = category.subcategories
    
    if subcategories.any?
      sections = [{
        title: "Select Subcategory",
        rows: subcategories.map { |sub|
          {
            id: "subcategory_#{sub.id}",
            title: sub.name,
            description: "Click to select"
          }
        }
      }]
      
      WhatsAppCloudService.send_interactive_list(
        phone_number,
        "Please select a subcategory for #{category.name}:",
        "Choose Subcategory",
        "Select Subcategory",
        sections
      )
      
      {
        success: true,
        response: nil,
        should_respond: false,
        interactive: true
      }
    else
      # No subcategories, proceed without them
      {
        success: true,
        response: "✅ Category selected: #{category.name}\nNo subcategories available.",
        should_respond: true
      }
    end
  rescue => e
    Rails.logger.error "WhatsappProductCreationService: Error sending subcategory selection - #{e.message}"
    {
      success: false,
      response: "Error loading subcategories. Please try again.",
      should_respond: true
    }
  end
  
  def self.handle_category_selection(session, selection_id)
    # Parse selection_id (format: "category_123" or "subcategory_456")
    if selection_id.start_with?('category_')
      category_id = selection_id.sub('category_', '').to_i
      category = Category.find_by(id: category_id)
      
      if category
        session.update_product_data('category_id', category.id)
        
        # Check if category has subcategories
        if category.subcategories.any?
          return send_subcategory_selection(session.phone_number, category.id)
        else
          return {
            success: true,
            response: "✅ Category selected: #{category.name}\n\nReply CONFIRM to post or EDIT to change anything.",
            should_respond: true
          }
        end
      else
        return { success: false, response: "Category not found. Please try again.", should_respond: true }
      end
    elsif selection_id.start_with?('subcategory_')
      subcategory_id = selection_id.sub('subcategory_', '').to_i
      subcategory = Subcategory.find_by(id: subcategory_id)
      
      if subcategory
        session.update_product_data('subcategory_id', subcategory.id)
        category = subcategory.category
        
        return {
          success: true,
          response: "✅ Subcategory selected: #{subcategory.name}\nCategory: #{category.name}\n\nReply CONFIRM to post or EDIT to change anything.",
          should_respond: true
        }
      else
        return { success: false, response: "Subcategory not found. Please try again.", should_respond: true }
      end
    else
      return { success: false, response: "Invalid selection. Please try again.", should_respond: true }
    end
  rescue => e
    Rails.logger.error "WhatsappProductCreationService: Error handling category selection - #{e.message}"
    { success: false, response: "Error processing selection. Please try again.", should_respond: true }
  end
  
  def self.handle_edit_input(session, message_content)
    input = message_content.to_s.strip.upcase
    
    if input == 'DONE'
      session.update(step: 3) # Return to confirm step
      return {
        success: true,
        response: "#{product_summary(session)}\n\nReply CONFIRM to post or EDIT to change anything.",
        should_respond: true
      }
    end
    
    # Handle price edit
    if input.start_with?('PRICE ')
      price = input.sub('PRICE ', '').gsub(/[^0-9.]/, '').to_f
      if price > 0 && price <= 1000000
        session.update_product_data('price', price)
        return {
          success: true,
          response: "✅ Price updated to KES #{price}\n\nReply DONE to finish editing or edit another field.",
          should_respond: true
        }
      else
        return { success: false, response: "Invalid price. Please enter a valid amount.", should_respond: true }
      end
    end
    
    # Handle brand edit
    if input.start_with?('BRAND ')
      brand = input.sub('BRAND ', '').strip
      if brand.length >= 2
        session.update_product_data('brand', brand)
        return {
          success: true,
          response: "✅ Brand updated to #{brand}\n\nReply DONE to finish editing or edit another field.",
          should_respond: true
        }
      else
        return { success: false, response: "Brand is too short. Please try again.", should_respond: true }
      end
    end
    
    # Handle condition edit
    if input.start_with?('CONDITION ')
      condition_value = input.sub('CONDITION ', '').strip.downcase
      valid_conditions = Ad.conditions.keys
      
      if valid_conditions.include?(condition_value)
        session.update_product_data('condition', condition_value)
        return {
          success: true,
          response: "✅ Condition updated to #{condition_value.humanize}\n\nReply DONE to finish editing or edit another field.",
          should_respond: true
        }
      else
        return { 
          success: false, 
          response: "Invalid condition. Valid options: #{valid_conditions.join(', ')}", 
          should_respond: true 
        }
      end
    end
    
    # Handle category edit
    if input == 'CATEGORY'
      return send_category_selection(session.phone_number)
    end
    
    {
      success: false,
      response: "Unknown command. Available commands: PRICE [amount], BRAND [name], CONDITION [1-5], CATEGORY, DONE",
      should_respond: true
    }
  end
  
  def self.process_images_step(session, media_urls, message_content = nil)
    if media_urls.any?
      existing_images = session.get_product_data('media') || []
      new_images = media_urls.first(5) # Max 5 images
      all_images = (existing_images + new_images).uniq.first(5)
      
      session.update_product_data('media', all_images)
      
      # In image-first flow, after receiving images, ask for title
      session.advance_step!
      
      return {
        success: true,
        response: "✅ Images received (#{all_images.length} image(s))!\n\nNow, please provide the product name (e.g., \"Samsung Galaxy S24\")",
        should_respond: true
      }
    elsif message_content && (message_content.to_s.strip.upcase == 'SKIP' || message_content.to_s.strip.upcase == 'DONE')
      # User wants to skip images, move to title step
      session.advance_step!
      {
        success: true,
        response: "Images skipped.\n\nNow, please provide the product name (e.g., \"Samsung Galaxy S24\")",
        should_respond: true
      }
    else
      {
        success: false,
        response: "Please send product images (1-5 photos) or type 'SKIP' to continue without images.",
        should_respond: true
      }
    end
  end
  
  def self.process_confirm_step(session, message_content)
    input = message_content.strip.upcase
    
    if input == 'CONFIRM'
      # Use AI-generated data if available, otherwise use user-provided data
      product_data = session.product_data
      
      # Set price from suggested price if not set by user
      if !product_data['price'] && product_data['suggested_price']
        session.update_product_data('price', product_data['suggested_price'])
      end
      
      # Use AI description if available
      if !product_data['description'] && product_data['ai_description']
        session.update_product_data('description', product_data['ai_description'])
      end
      
      # Set default price if still not set
      if !product_data['price']
        return {
          success: false,
          response: "Price is required. Reply 'EDIT' to set price or 'CANCEL' to start over.",
          should_respond: true
        }
      end
      
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
        response: "Please reply 'CONFIRM' to create this product, 'EDIT' to change details, or 'CANCEL' to start over.",
        should_respond: true
      }
    end
  end
  
  def self.create_product(session)
    product_data = session.product_data
    
    # Validate required fields
    required_fields = ['title', 'price', 'category_id']
    missing_fields = required_fields.select { |field| product_data[field].blank? }
    
    if missing_fields.any?
      return {
        success: false,
        error: "Missing required fields: #{missing_fields.join(', ')}"
      }
    end
    
    # Set default values for optional fields
    brand = product_data['brand'] || 'Unknown'
    condition = product_data['condition'] || 'second_hand'
    description = product_data['description'] || product_data['ai_description'] || "Quality product available. Contact seller for more details."
    media = product_data['media'] || []
    subcategory_id = product_data['subcategory_id']
    
    # Create the ad with subcategory support
    ad_params = {
      title: product_data['title'],
      description: description,
      price: product_data['price'],
      category_id: product_data['category_id'],
      brand: brand,
      condition: condition,
      media: media,
      is_added_by_sales: false
    }
    
    # Add subcategory if available
    ad_params[:subcategory_id] = subcategory_id if subcategory_id.present?
    
    ad = session.seller.ads.build(ad_params)
    
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
    Rails.logger.error "WhatsappProductCreationService: Error creating product - #{e.message}"
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
    
    if data['subcategory_id']
      subcategory = Subcategory.find_by(id: data['subcategory_id'])
      summary += "*Subcategory:* #{subcategory&.name || 'N/A'}\n"
    end
    
    if data['media']&.any?
      summary += "*Images:* #{data['media'].length} image(s)\n"
    else
      summary += "*Images:* None\n"
    end
    
    summary
  end
  
  def self.welcome_message_image_first
    "🚀 *Let's add your product!*\n\nI'll analyze your photos to automatically fill in product details.\n\n📸 Step 1: Send 1-3 photos of your product\n   (or type 'SKIP' to continue without photos)\n\nSend 'CANCEL' at any time to stop."
  end
  
  def self.welcome_message
    "🚀 *Let's add your product!*\n\nI'll guide you through creating a product listing step by step.\n\nStep 1/8: Please provide a title for your product (minimum 10 characters):\n\nSend 'CANCEL' at any time to stop."
  end
  
  def self.help_message
    "📱 *WhatsApp Product Creation Help*\n\nCommands:\n• ADD - Start adding a new product\n• CANCEL - Cancel current product creation\n• HELP - Show this help message\n\nNew Image-First Flow:\n1. Send product photos\n2. Provide product name\n3. AI analyzes and auto-fills details\n4. Confirm or edit\n\nSend 'ADD' to get started!"
  end
end
