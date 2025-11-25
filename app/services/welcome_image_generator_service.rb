# app/services/welcome_image_generator_service.rb
begin
  require 'mini_magick'
  MINI_MAGICK_AVAILABLE = true
rescue LoadError
  MINI_MAGICK_AVAILABLE = false
  Rails.logger.warn "MiniMagick gem not available - welcome images will be disabled"
end

begin
  require 'rqrcode'
  require 'chunky_png'
  QR_CODE_AVAILABLE = true
rescue LoadError
  QR_CODE_AVAILABLE = false
  Rails.logger.warn "RQrcode gem not available - QR codes will be disabled"
end

class WelcomeImageGeneratorService
  # Tier-based color schemes - Business card style
  TIER_COLORS = {
    1 => { # Free
      bg: '#F5F5F5',
      accent: '#808080',
      text: '#333333',
      foil: '#C0C0C0',
      border: '#E0E0E0'
    },
    2 => { # Basic
      bg: '#1A1A2E',
      accent: '#4A90E2',
      text: '#FFFFFF',
      foil: '#5BA0F2',
      border: '#2A2A3E'
    },
    3 => { # Standard
      bg: '#1A0D1A',
      accent: '#9B59B6',
      text: '#FFFFFF',
      foil: '#AB6BC6',
      border: '#2A1D2A'
    },
    4 => { # Premium - Black matte with gold foil
      bg: '#0A0A0A',
      accent: '#D4AF37',
      text: '#FFFFFF',
      foil: '#FFD700',
      border: '#1A1A1A'
    }
  }.freeze

  def self.generate(user)
    return nil unless user.present?
    return nil unless MINI_MAGICK_AVAILABLE
    
    user_type = user.class.name.downcase
    return nil unless user_type == 'seller' # Only generate for sellers with shop data
    
    # Create temp directory for images if it doesn't exist
    temp_dir = Rails.root.join('tmp', 'welcome_images')
    FileUtils.mkdir_p(temp_dir) unless Dir.exist?(temp_dir)
    
    # Generate unique filename
    filename = "welcome_#{user.id}_#{Time.current.to_i}.png"
    image_path = temp_dir.join(filename)
    
    begin
      # Get seller data
      seller = user.is_a?(Seller) ? user : nil
      return nil unless seller
      
      # Get tier information
      tier = seller.tier || seller.seller_tier&.tier
      tier_id = tier&.id || 1 # Default to Free tier
      tier_name = tier&.name || 'Free'
      
      # Get tier colors
      colors = TIER_COLORS[tier_id] || TIER_COLORS[1]
      
      # Get shop data
      shop_name = seller.enterprise_name || seller.fullname || 'Your Shop'
      profile_image_url = seller.profile_picture
      phone_number = seller.phone_number
      email = seller.email
      
      # Generate QR code (shop URL or welcome message)
      qr_code_path = generate_qr_code(seller, temp_dir) if QR_CODE_AVAILABLE
      
      # Business card dimensions (standard: 3.5" x 2" at 300 DPI = 1050x600)
      # Using larger size for better quality: 1400x800 (print-ready)
      width = 1400
      height = 800
      
      magick_cmd = `which magick 2>/dev/null`.strip.present? ? "magick" : "convert"
      
      # Create base image with solid background (matte black for premium, dark for others)
      success = system("#{magick_cmd} -size #{width}x#{height} xc:#{colors[:bg]} '#{image_path}'")
      
      unless success && File.exist?(image_path)
        Rails.logger.error "Failed to create gradient image"
        return nil
      end
      
      image = MiniMagick::Image.open(image_path.to_s)
      
      # Add subtle texture/pattern overlay for matte effect
      add_matte_texture(image, colors, width, height, magick_cmd)
      
      # Add decorative border/corner markers (like the reference design)
      add_corner_markers(image, colors, width, height, magick_cmd)
      
      # Add profile picture if available (circular, left side)
      if profile_image_url.present?
        add_profile_picture_business_card(image, profile_image_url, width, height, magick_cmd, colors)
      end
      
      # Add shop name (prominent, gold foil style)
      add_shop_name_business_card(image, shop_name, colors, width, height)
      
      # Add tier badge (subtle, top right)
      add_tier_badge_business_card(image, tier_name, colors, width, height, magick_cmd)
      
      # Add contact information
      add_contact_info(image, phone_number, email, colors, width, height)
      
      # Add QR code (right side, elegant placement)
      if qr_code_path && File.exist?(qr_code_path)
        add_qr_code_business_card(image, qr_code_path, width, height, magick_cmd, colors)
      end
      
      # Add brand logo/text (bottom)
      add_brand_footer_business_card(image, colors, width, height)
      
      # Save the final image
      image.write(image_path.to_s)
      
      # Cleanup QR code temp file
      File.delete(qr_code_path) if qr_code_path && File.exist?(qr_code_path)
      
      absolute_path = File.expand_path(image_path)
      Rails.logger.info "✅ Welcome image generated: #{absolute_path}"
      absolute_path
    rescue => e
      Rails.logger.error "❌ Error generating welcome image: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      
      File.delete(image_path) if File.exist?(image_path)
      File.delete(qr_code_path) if qr_code_path && File.exist?(qr_code_path)
      
      nil
    end
  end
  
  private
  
  def self.generate_qr_code(seller, temp_dir)
    return nil unless QR_CODE_AVAILABLE
    
    begin
      # Generate QR code with shop URL
      base_url = if Rails.env.development?
        ENV.fetch('FRONTEND_URL', 'http://localhost:3000')
      else
        ENV.fetch('FRONTEND_URL', 'https://carboncube-ke.com')
      end
      
      shop_url = "#{base_url}/shop/#{seller.username || seller.id}"
      qr = RQRCode::QRCode.new(shop_url)
      
      qr_code_path = temp_dir.join("qr_#{seller.id}_#{Time.current.to_i}.png")
      
      # Generate PNG QR code with proper options
      png = qr.as_png(
        bit_depth: 1,
        border_modules: 2,
        color_mode: ChunkyPNG::COLOR_GRAYSCALE,
        color: 'black',
        file: nil,
        fill: 'white',
        module_px_size: 6,
        resize_exactly_to: false,
        resize_gte_to: false,
        size: 250
      )
      
      File.binwrite(qr_code_path, png.to_s)
      qr_code_path.to_s
    rescue => e
      Rails.logger.error "Failed to generate QR code: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      nil
    end
  end
  
  def self.add_matte_texture(image, colors, width, height, magick_cmd)
    # Add subtle matte texture effect
    begin
      temp_texture = Rails.root.join('tmp', 'welcome_images', "texture_#{Time.current.to_i}.png")
      # Create noise pattern for matte effect
      texture_cmd = "#{magick_cmd} -size #{width}x#{height} xc:#{colors[:bg]} +noise Random -blur 0x0.5 -alpha set -channel A -evaluate multiply 0.05 +channel"
      success = system("#{texture_cmd} '#{temp_texture}'")
      
      if success && File.exist?(temp_texture)
        image.composite(MiniMagick::Image.open(temp_texture.to_s)) do |c|
          c.compose "Overlay"
        end
        File.delete(temp_texture)
      end
    rescue => e
      Rails.logger.warn "Could not add matte texture: #{e.message}"
    end
  end
  
  def self.add_corner_markers(image, colors, width, height, magick_cmd)
    # Add L-shaped corner markers like the reference design
    begin
      marker_size = 20
      marker_thickness = 2
      corner_offset = 30
      
      # Draw corner markers in gold foil color
      image.combine_options do |c|
        c.stroke colors[:foil]
        c.strokewidth marker_thickness
        c.fill 'none'
        # Top-left
        c.draw "line #{corner_offset},#{corner_offset} #{corner_offset + marker_size},#{corner_offset}"
        c.draw "line #{corner_offset},#{corner_offset} #{corner_offset},#{corner_offset + marker_size}"
        # Top-right
        c.draw "line #{width - corner_offset - marker_size},#{corner_offset} #{width - corner_offset},#{corner_offset}"
        c.draw "line #{width - corner_offset},#{corner_offset} #{width - corner_offset},#{corner_offset + marker_size}"
        # Bottom-left
        c.draw "line #{corner_offset},#{height - corner_offset - marker_size} #{corner_offset},#{height - corner_offset}"
        c.draw "line #{corner_offset},#{height - corner_offset} #{corner_offset + marker_size},#{height - corner_offset}"
        # Bottom-right
        c.draw "line #{width - corner_offset - marker_size},#{height - corner_offset} #{width - corner_offset},#{height - corner_offset}"
        c.draw "line #{width - corner_offset},#{height - corner_offset - marker_size} #{width - corner_offset},#{height - corner_offset}"
      end
    rescue => e
      Rails.logger.warn "Could not add corner markers: #{e.message}"
    end
  end
  
  def self.add_profile_picture_business_card(image, profile_url, width, height, magick_cmd, colors)
    begin
      require 'open-uri'
      require 'timeout'
      require 'tempfile'
      
      temp_profile = Tempfile.new(['profile', '.jpg'])
      temp_profile.binmode
      
      Timeout.timeout(5) do
        URI.open(profile_url, read_timeout: 5) do |uri|
          temp_profile.write(uri.read)
        end
      end
      temp_profile.close
      
      # Circular profile picture, left side
      profile_size = 180
      profile_x = 100
      profile_y = height / 2 - profile_size / 2
      
      circular_profile = Rails.root.join('tmp', 'welcome_images', "profile_#{Time.current.to_i}.png")
      bordered_profile = Rails.root.join('tmp', 'welcome_images', "profile_bordered_#{Time.current.to_i}.png")
      profile_cmd = "#{magick_cmd} '#{temp_profile.path}' -resize #{profile_size}x#{profile_size}^ -gravity center -extent #{profile_size}x#{profile_size} -alpha set \\( +clone -fill black -colorize 100% -draw 'fill white circle #{profile_size/2},#{profile_size/2} #{profile_size/2},0' \\) -alpha off -compose CopyOpacity -composite '#{circular_profile}'"
      
      system(profile_cmd)
      
      if File.exist?(circular_profile)
        # Add gold border
        system("#{magick_cmd} '#{circular_profile}' -bordercolor #{colors[:foil]} -border 3 '#{bordered_profile}'")
        circular_profile = bordered_profile if File.exist?(bordered_profile)
      end
      
      success = system(profile_cmd + " '#{circular_profile}'")
      
      if success && File.exist?(circular_profile)
        image.composite(MiniMagick::Image.open(circular_profile.to_s)) do |c|
          c.compose "Over"
          c.geometry "+#{profile_x}+#{profile_y}"
        end
        File.delete(circular_profile)
      end
      
      temp_profile.unlink
    rescue Timeout::Error
      Rails.logger.warn "Timeout downloading profile picture"
    rescue => e
      Rails.logger.warn "Could not add profile picture: #{e.message}"
    end
  end
  
  def self.add_shop_name_business_card(image, shop_name, colors, width, height)
    # Shop name - prominent, gold foil style (left side, next to profile)
    image.combine_options do |c|
      c.pointsize 56
      c.fill colors[:foil]
      c.gravity 'NorthWest'
      c.annotate "+320+200", shop_name.upcase
    end
    
    # Add subtle underline
    image.combine_options do |c|
      c.stroke colors[:foil]
      c.strokewidth 2
      c.draw "line 320,#{height/2 - 60} #{width - 400},#{height/2 - 60}"
    end
  end
  
  def self.add_tier_badge_business_card(image, tier_name, colors, width, height, magick_cmd)
    # Subtle tier badge in top right
    badge_x = width - 200
    badge_y = 40
    
    image.combine_options do |c|
      c.pointsize 20
      c.fill colors[:foil]
      c.gravity 'NorthEast'
      c.annotate "+40+#{badge_y}", tier_name.upcase
    end
  rescue => e
    Rails.logger.warn "Could not add tier badge: #{e.message}"
  end
  
  def self.add_contact_info(image, phone_number, email, colors, width, height)
    # Contact information (left side, below shop name)
    y_start = height / 2 - 20
    
    if phone_number.present?
      image.combine_options do |c|
        c.pointsize 24
        c.fill colors[:foil]
        c.gravity 'NorthWest'
        c.annotate "+320+#{y_start}", "📞 #{phone_number}"
      end
    end
    
    if email.present?
      email_y = y_start + 50
      # Truncate email if too long
      display_email = email.length > 30 ? "#{email[0..27]}..." : email
      image.combine_options do |c|
        c.pointsize 22
        c.fill colors[:foil]
        c.gravity 'NorthWest'
        c.annotate "+320+#{email_y}", "✉ #{display_email}"
      end
    end
  end
  
  def self.add_qr_code_business_card(image, qr_code_path, width, height, magick_cmd, colors)
    # QR code on right side, elegant placement
    qr_size = 200
    qr_x = width - qr_size - 80
    qr_y = height / 2 - qr_size / 2
    
    # Convert QR code to gold foil color
    gold_qr = Rails.root.join('tmp', 'welcome_images', "qr_gold_#{Time.current.to_i}.png")
    system("#{magick_cmd} '#{qr_code_path}' -resize #{qr_size}x#{qr_size} -fuzz 50% -fill '#{colors[:foil]}' -opaque black -fuzz 50% -fill '#{colors[:bg]}' -opaque white '#{gold_qr}'")
    
    if File.exist?(gold_qr)
      image.composite(MiniMagick::Image.open(gold_qr.to_s)) do |c|
        c.compose "Over"
        c.geometry "+#{qr_x}+#{qr_y}"
      end
      
      # Add subtle label below QR code
      image.combine_options do |c|
        c.pointsize 16
        c.fill colors[:foil]
        c.gravity 'NorthWest'
        c.annotate "+#{qr_x}+#{qr_y + qr_size + 15}", "Scan to visit"
      end
      
      File.delete(gold_qr)
    end
  rescue => e
    Rails.logger.warn "Could not add QR code: #{e.message}"
  end
  
  def self.add_brand_footer_business_card(image, colors, width, height)
    # Brand name at bottom (subtle, gold foil)
    image.combine_options do |c|
      c.pointsize 28
      c.fill colors[:foil]
      c.gravity 'South'
      c.annotate "+0+40", "CARBON CUBE KENYA"
    end
    
    # Website URL
    website = 'carboncube-ke.com'
    image.combine_options do |c|
      c.pointsize 18
      c.fill colors[:foil]
      c.gravity 'South'
      c.annotate "+0+75", website
    end
    
    # Add print instruction text (like reference design)
    image.combine_options do |c|
      c.pointsize 12
      c.fill colors[:foil]
      c.gravity 'SouthWest'
      c.annotate "+30+30", "PRINT WITH MATTE PAPER AND GOLD FOIL"
    end
  end
  
  def self.get_user_display_name(user)
    case user.class.name
    when 'Buyer'
      user.fullname.present? ? user.fullname : (user.username.present? ? user.username : user.email.split('@').first)
    when 'Seller'
      user.enterprise_name.present? ? user.enterprise_name : (user.fullname.present? ? user.fullname : user.email.split('@').first)
    else
      user.email.split('@').first
    end
  end
  
  # Clean up old welcome images (older than 1 hour)
  def self.cleanup_old_images
    temp_dir = Rails.root.join('tmp', 'welcome_images')
    return unless Dir.exist?(temp_dir)
    
    cutoff_time = 1.hour.ago
    deleted_count = 0
    
    Dir.glob(temp_dir.join('welcome_*.png')).each do |file_path|
      if File.mtime(file_path) < cutoff_time
        File.delete(file_path)
        deleted_count += 1
      end
    end
    
    Rails.logger.info "🧹 Cleaned up #{deleted_count} old welcome images" if deleted_count > 0
    deleted_count
  end
end
