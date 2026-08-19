# frozen_string_literal: true

require 'rqrcode'
require 'fileutils'
require 'cgi'
require 'base64'
require 'open-uri'
require 'timeout'

class SellerQrStandeeGeneratorService
  WIDTH = 480
  HEIGHT = 680

  def self.generate(seller, theme_hex: '#f59e0b')
    return nil unless seller.present?

    temp_dir = Rails.root.join('tmp', 'qr_standees')
    FileUtils.mkdir_p(temp_dir) unless Dir.exist?(temp_dir)

    slug = (seller.enterprise_name || seller.username || seller.id.to_s).parameterize
    output_png = temp_dir.join("standee_#{seller.id}_#{Time.current.to_i}.png").to_s
    temp_svg = temp_dir.join("standee_#{seller.id}_#{Time.current.to_i}.svg").to_s

    begin
      shop_name = (seller.enterprise_name.presence || seller.fullname.presence || 'Verified Shop').to_s.strip
      tier_name = (seller.tier&.name.presence || seller.seller_tier&.tier&.name.presence || 'PREMIUM').upcase + ' SELLER'
      initials = shop_name.split(/\s+/).filter_map { |w| w[0]&.upcase }.first(2).join.presence || 'S'

      frontend_base = ENV['NEXT_PUBLIC_SITE_URL'].presence ||
                      ENV['FRONTEND_URL'].presence ||
                      ENV['REACT_APP_SITE_URL'].presence ||
                      (Rails.env.development? ? 'http://localhost:3000' : 'https://carboncube-ke.com')
      frontend_base = frontend_base.chomp('/')

      display_domain = begin
        URI.parse(frontend_base).host || 'carboncube-ke.com'
      rescue
        'carboncube-ke.com'
      end

      shop_url = "#{frontend_base}/shop/#{slug}?utm_source=offline_qr&utm_medium=pass&utm_campaign=welcome_qr"

      # 1. Load official Carbon Cube Kenya logo
      logo_path = Rails.root.join('app/assets/images/logo.png')
      logo_path = Rails.root.join('../frontend/public/logo.png') unless File.exist?(logo_path)
      
      carbon_logo_b64 = nil
      if File.exist?(logo_path)
        carbon_logo_b64 = Base64.strict_encode64(File.binread(logo_path))
      end

      # 2. Try loading seller profile avatar image if available
      seller_avatar_b64 = nil
      if seller.profile_picture.present?
        begin
          Timeout.timeout(3) do
            avatar_url = seller.profile_picture
            avatar_url = "https:#{avatar_url}" if avatar_url.start_with?('//')
            if avatar_url.start_with?('http://', 'https://')
              URI.open(avatar_url, 'rb', read_timeout: 3) do |f|
                seller_avatar_b64 = Base64.strict_encode64(f.read)
              end
            end
          end
        rescue => e
          Rails.logger.warn "Could not fetch seller avatar: #{e.message}"
        end
      end

      # 3. Generate QR Matrix modules in SVG
      qr = RQRCode::QRCode.new(shop_url, level: :h)
      qr_module_count = qr.modules.length
      qr_view_size = 280
      qr_mod_size = qr_view_size.to_f / qr_module_count

      qr_rects = []
      qr.modules.each_with_index do |row, y|
        row.each_with_index do |dark, x|
          next unless dark
          rx = (x * qr_mod_size).round(2)
          ry = (y * qr_mod_size).round(2)
          rw = qr_mod_size.round(2) + 0.2
          qr_rects << %(<rect x="#{rx}" y="#{ry}" width="#{rw}" height="#{rw}" fill="#{theme_hex}"/>)
        end
      end
      qr_svg_content = qr_rects.join

      center_x = WIDTH / 2
      avatar_cy = 78
      avatar_r = 38
      inner_r = 32

      qr_box_size = 310
      qr_box_x = (WIDTH - qr_box_size) / 2
      qr_box_y = 215

      qr_x = (WIDTH - qr_view_size) / 2
      qr_y = qr_box_y + (qr_box_size - qr_view_size) / 2

      center_logo_cy = qr_y + qr_view_size / 2
      center_logo_r = 24

      name_approx_len = [shop_name.length * 12, 280].min
      badge_offset_x = (name_approx_len / 2) + 14

      # Avatar SVG snippet
      top_avatar_content = if seller_avatar_b64
        %(<clipPath id="avatarClip"><circle cx="#{center_x}" cy="#{avatar_cy}" r="#{inner_r}"/></clipPath>
          <image href="data:image/png;base64,#{seller_avatar_b64}" x="#{center_x - inner_r}" y="#{avatar_cy - inner_r}" width="#{inner_r * 2}" height="#{inner_r * 2}" clip-path="url(#avatarClip)" preserveAspectRatio="xMidYMid slice"/>)
      else
        %(<circle cx="#{center_x}" cy="#{avatar_cy}" r="#{inner_r}" fill="#0284c7"/>
          <text x="#{center_x}" y="#{avatar_cy + 9}" class="font-sans" font-size="24" font-weight="900" fill="#ffffff" text-anchor="middle">#{CGI.escapeHTML(initials)}</text>)
      end

      center_logo_content = if seller_avatar_b64
        inner_center_r = center_logo_r - 5
        %(<clipPath id="centerClip"><circle cx="#{center_x}" cy="#{center_logo_cy}" r="#{inner_center_r}"/></clipPath>
          <image href="data:image/png;base64,#{seller_avatar_b64}" x="#{center_x - inner_center_r}" y="#{center_logo_cy - inner_center_r}" width="#{inner_center_r * 2}" height="#{inner_center_r * 2}" clip-path="url(#centerClip)" preserveAspectRatio="xMidYMid slice"/>)
      else
        %(<circle cx="#{center_x}" cy="#{center_logo_cy}" r="#{center_logo_r - 5}" fill="#0284c7"/>
          <text x="#{center_x}" y="#{center_logo_cy + 6}" class="font-sans" font-size="14" font-weight="900" fill="#ffffff" text-anchor="middle">#{CGI.escapeHTML(initials)}</text>)
      end

      # Footer logo snippet
      footer_logo_content = if carbon_logo_b64
        %(<image href="data:image/png;base64,#{carbon_logo_b64}" x="0" y="0" width="22" height="22" preserveAspectRatio="xMidYMid meet"/>)
      else
        %(<polygon points="10,0 20,5.8 20,17.4 10,23.2 0,17.4 0,5.8" fill="#{theme_hex}"/>)
      end

      svg = <<~SVG
        <svg width="#{WIDTH}" height="#{HEIGHT}" viewBox="0 0 #{WIDTH} #{HEIGHT}" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <style>
              .font-sans { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif; }
              .font-mono { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }
            </style>
          </defs>

          <!-- Outer Card Background with Rounded Corners -->
          <rect x="8" y="8" width="#{WIDTH - 16}" height="#{HEIGHT - 16}" rx="32" ry="32" fill="#fffbf5" stroke="#e2e8f0" stroke-width="2"/>

          <!-- Top Circular Avatar Container -->
          <circle cx="#{center_x}" cy="#{avatar_cy}" r="#{avatar_r}" fill="#ffffff" stroke="#{theme_hex}" stroke-width="3.5"/>
          #{top_avatar_content}

          <!-- Merchant Name & Outlined Verified Seal -->
          <g transform="translate(#{center_x}, 152)">
            <text x="0" y="0" class="font-sans" font-size="22" font-weight="800" fill="#0f172a" text-anchor="middle">#{CGI.escapeHTML(shop_name)}</text>
            <!-- 12-point seal badge -->
            <g transform="translate(#{badge_offset_x}, -6) scale(0.85)">
              <polygon points="0,-10 2.6,-7.5 6,-8 6.5,-4.5 9.5,-2.5 8,1 9.5,4.5 6.5,6.5 6,10 2.6,9.5 0,12 -2.6,9.5 -6,10 -6.5,6.5 -9.5,4.5 -8,1 -9.5,-2.5 -6.5,-4.5 -6,-8 -2.6,-7.5" fill="none" stroke="#{theme_hex}" stroke-width="2"/>
              <path d="M -3.5 0.5 L -1 3.5 L 3.5 -2.5" fill="none" stroke="#{theme_hex}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
            </g>
          </g>

          <!-- Tier Badge Pill -->
          <g transform="translate(#{center_x}, 180)">
            <rect x="-65" y="-10" width="130" height="20" rx="10" ry="10" fill="#fef3c7"/>
            <text x="0" y="4" class="font-sans" font-size="9.5" font-weight="800" fill="#92400e" text-anchor="middle" letter-spacing="0.6">#{CGI.escapeHTML(tier_name)}</text>
          </g>

          <!-- QR Code Container Box -->
          <rect x="#{qr_box_x}" y="#{qr_box_y}" width="#{qr_box_size}" height="#{qr_box_size}" rx="24" ry="24" fill="#ffffff" stroke="#f1f5f9" stroke-width="2"/>

          <!-- QR Code Matrix -->
          <g transform="translate(#{qr_x}, #{qr_y})">
            #{qr_svg_content}
          </g>

          <!-- Center Circular Logo on QR Code -->
          <circle cx="#{center_x}" cy="#{center_logo_cy}" r="#{center_logo_r}" fill="#ffffff" stroke="#{theme_hex}" stroke-width="3"/>
          #{center_logo_content}

          <!-- Call To Action -->
          <text x="#{center_x}" y="562" class="font-sans" font-size="14" font-weight="700" fill="#0f172a" text-anchor="middle">Scan to browse our catalog &amp; place orders</text>

          <!-- Divider Line -->
          <line x1="36" y1="595" x2="#{WIDTH - 36}" y2="595" stroke="#f1f5f9" stroke-width="1.5"/>

          <!-- Footer Branding with Official Logo -->
          <g transform="translate(36, 618)">
            #{footer_logo_content}
            <text x="30" y="16" class="font-sans" font-size="13" font-weight="700" fill="#1e293b">Carbon Cube Kenya</text>
          </g>
          <text x="#{WIDTH - 36}" y="634" class="font-mono" font-size="11.5" font-weight="500" fill="#94a3b8" text-anchor="end">#{CGI.escapeHTML(display_domain)}</text>
        </svg>
      SVG

      File.write(temp_svg, svg)

      # Render SVG to high-res PNG using Node.js + Sharp
      script_path = Rails.root.join('lib', 'scripts', 'render_qr_standee.cjs')
      cmd = %(NODE_PATH=#{Rails.root.join('../frontend/node_modules')} node "#{script_path}" "#{temp_svg}" "#{output_png}")
      
      success = system(cmd)

      File.delete(temp_svg) if File.exist?(temp_svg)

      if success && File.exist?(output_png)
        output_png
      else
        Rails.logger.error "❌ Failed to render SVG with Sharp"
        nil
      end
    rescue => e
      Rails.logger.error "❌ SellerQrStandeeGeneratorService error: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      File.delete(temp_svg) if File.exist?(temp_svg)
      nil
    end
  end
end
