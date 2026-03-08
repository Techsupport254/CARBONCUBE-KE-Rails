class MarketingMailer < ApplicationMailer
  helper ActionView::Helpers::NumberHelper
  layout false

  def valentines_campaign(seller)
    @seller = seller
    @fullname = seller.fullname
    @enterprise_name = seller.enterprise_name
    
    # Ads Count
    @ads_count = seller.ads_count
    
    # Profile Picture Logic
    raw_pic = seller.profile_picture
    if raw_pic.present? && !raw_pic.to_s.start_with?('/cached_profile_pictures/')
      @profile_picture = raw_pic
    else
      # Robust Fallback to UI Avatars
      # Ensure name is safe for URL
      safe_name = (@enterprise_name.presence || @fullname.presence || "Carbon User").to_s.gsub(/[^a-zA-Z0-9\s]/, '').strip
      safe_name = "CU" if safe_name.blank?
      @profile_picture = "https://ui-avatars.com/api/?name=#{URI.encode_www_form_component(safe_name)}&background=FED7D7&color=E53E3E&size=128&bold=true&format=png"
    end
    
    # Tier Name
    @tier_name = seller.seller_tier&.tier&.name || "Free"
    
    # Total Clicks
    @total_clicks = ClickEvent.where(ad_id: seller.ads.select(:id), event_type: 'Ad-Click').count

    # Identify Top Performing Ad
    top_ad_data = ClickEvent.where(ad_id: seller.ads.select(:id), event_type: 'Ad-Click')
                            .group(:ad_id)
                            .order('count_all DESC')
                            .count
                            .first
    
    # top_ad_data is [ad_id, count] or nil
    if top_ad_data
      @top_ad = Ad.find_by(id: top_ad_data[0])
      @top_ad_clicks = top_ad_data[1]
    elsif seller.ads.exists?
       # Fallback: Just grab the latest active ad if no clicks yet
       @top_ad = seller.ads.active.order(created_at: :desc).first
       @top_ad_clicks = 0
    end

    # Days since last ad
    last_ad = seller.ads.order(created_at: :desc).first
    @days_since_last_ad = last_ad ? ((Time.current - last_ad.created_at) / 1.day).to_i : 999
    
    # Gender
    @gender = seller.gender.presence || "Legend" 
    
    # Timestamp (for footer or metadata matching welcome_mailer)
    @timestamp = Time.current.in_time_zone("Nairobi").strftime("%B %d, %Y at %I:%M %p")

    # Headers to avoid "Promotions" tab
    headers['X-Priority'] = '1' # High priority
    headers['X-MSMail-Priority'] = 'High'
    headers['Importance'] = 'High'
    headers['Precedence'] = nil # Explicitly override ApplicationMailer's 'bulk'
    
    # Intentionally removing List-Unsubscribe from HEADER to look less like a newsletter
    headers['List-Unsubscribe'] = nil
    headers['List-Unsubscribe-Post'] = nil

    # Force unique thread by adding invisible char or ID to subject if needed, 
    # but simplest is to just make the subject unique.
    unique_id = Time.current.to_i.to_s[-4..-1]

    # Explicitly set a unique Message-ID to break threading
    headers['Message-ID'] = "<#{Time.current.to_f}-#{seller.id}@carboncube-ke.com>"
    headers['X-Entity-Ref-ID'] = unique_id

    mail(
      to: seller.email,
      subject: "We’ve got feelings for your shop! ❤️ (Performance Update)",
      from: "Carbon Cube Team <#{ENV['BREVO_EMAIL']}>"
    )
  end
  def product_review_request(name:, email:, products:)
    @name = name
    @products = products

    # Override ApplicationMailer's bulk/newsletter headers AFTER they're set
    # These must be set here to override the before_action in ApplicationMailer
    headers['Precedence'] = nil
    headers['List-Unsubscribe'] = nil
    headers['List-Unsubscribe-Post'] = nil
    headers['X-Auto-Response-Suppress'] = nil
    
    # Make it look transactional, not promotional
    headers['X-Priority'] = '1'
    headers['X-MSMail-Priority'] = 'High'
    headers['Importance'] = 'High'
    headers['X-PM-Message-Stream'] = 'outbound' # Transactional stream signal
    headers['Feedback-ID'] = "review_request:carboncube" # Gmail category signal

    # Unique message ID to prevent threading
    headers['Message-ID'] = "<#{Time.current.to_f}-review-#{SecureRandom.hex(4)}@carboncube-ke.com>"
    headers['X-Entity-Ref-ID'] = SecureRandom.hex(6)
    headers['In-Reply-To'] = nil
    headers['References'] = nil

    first_name = name.to_s.split.first || name

    mail(
      to: email,
      subject: "#{first_name}, how was your experience?",
      from: "Carbon Cube Kenya <#{ENV['BREVO_EMAIL']}>",
      reply_to: ENV['BREVO_EMAIL']
    ) do |format|
      # Read the MJML template, substitute variables, then render
      template_path = Rails.root.join('app', 'views', 'mailers', 'product_review_request.mjml')
      mjml_source = File.read(template_path)

      # Replace Handlebars-style variables
      mjml_source.gsub!('{{name}}', @name)

      # Replace product loop
      if mjml_source.include?('{{#each products}}')
        product_block_match = mjml_source.match(/\{\{#each products\}\}(.*?)\{\{\/each\}\}/m)
        if product_block_match
          product_template = product_block_match[1]
          rendered_products = @products.map do |product|
            block = product_template.dup
            block.gsub!('{{this.image_url}}', product[:image_url].to_s)
            block.gsub!('{{this.title}}', product[:title].to_s)
            block.gsub!('{{this.seller_name}}', product[:seller_name].to_s)
            block.gsub!('{{this.review_url}}', product[:review_url].to_s)
            block
          end.join("\n")
          mjml_source.gsub!(product_block_match[0], rendered_products)
        end
      end

      # Try to compile MJML to HTML
      html_content = begin
        require 'open3'
        stdout, stderr, status = Open3.capture3('npx', 'mjml', '--stdin', stdin_data: mjml_source)
        if status.success?
          stdout
        else
          Rails.logger.warn "MJML compilation failed: #{stderr}"
          mjml_source
        end
      rescue Errno::ENOENT => e
        Rails.logger.warn "MJML binary not found: #{e.message}. Sending raw MJML."
        mjml_source
      end

      format.html { render plain: html_content }
    end
  end

  # Helper to build proper review URL for an ad
  def self.review_url_for(ad)
    slug = Ad.slugify(ad.title)
    "https://carboncube-ke.com/ads/#{slug}/review?id=#{ad.id}"
  end
end
