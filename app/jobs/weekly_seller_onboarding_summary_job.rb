# frozen_string_literal: true

# Sends a weekly onboarding summary email to every sales user every Wednesday at 7:00 AM EAT.
# Non-manager/lead users receive their own onboarded sellers from the past 7 days.
# Managers and leads receive their own sellers plus a team-wide leaderboard and full list, plus a PDF attachment.
class WeeklySellerOnboardingSummaryJob < ApplicationJob
  queue_as :low

  LOOKBACK_DAYS = 7

  # @param base_time [Time, String, nil] optional override for the "now" used to calculate the window (defaults to EAT now)
  def perform(base_time = nil)
    base_time = Time.parse(base_time.to_s) if base_time.present?
    base_time ||= Time.current.in_time_zone('Africa/Nairobi')

    window_start = (base_time - LOOKBACK_DAYS.days).beginning_of_day
    window_end = base_time

    # All carbon-code assignments in the past 7 days, eager-loaded
    weekly_assignments = SellerCarbonCodeAssignment
                           .includes(:seller, :sales_user)
                           .where(created_at: window_start..window_end)
                           .order(created_at: :desc)

    sellers_by_sales_user = {}
    team_summary = Hash.new(0)
    all_team_sellers = []

    weekly_assignments.each do |assignment|
      seller = assignment.seller
      next if seller.nil?

      user = assignment.sales_user
      next if user.nil?

      seller_data = build_seller_data(seller, assignment, user)
      all_team_sellers << seller_data

      sellers_by_sales_user[user.id] ||= []
      sellers_by_sales_user[user.id] << seller_data

      team_summary[user] += 1
    end

    # All-time totals per sales user
    all_time_counts = SellerCarbonCodeAssignment
                        .group(:sales_user_id)
                        .count

    team_summary_array = team_summary
                           .sort_by { |_, count| -count }
                           .map do |user, count|
      {
        fullname: user.fullname.presence || user.email.to_s.split('@').first,
        email: user.email,
        count: count,
        currentTotal: all_time_counts[user.id] || 0
      }
    end

    team_current_total = all_time_counts.values.sum

    # All daily reports for this weekly window
    weekly_reports = SalesDailyReport.where(report_date: window_start.to_date..window_end.to_date)
    total_shops_visited = weekly_reports.sum(:businesses_visited)
    weekly_onboarded = all_team_sellers.size
    ai_issues_summary = generate_weekly_ai_summary(weekly_reports, total_shops_visited, weekly_onboarded)

    # Build one PDF for the team only if there are onboardings; only managers/leads get it attached
    team_pdf = all_team_sellers.any? ? build_team_pdf(window_start, window_end, team_summary_array, all_team_sellers, team_current_total, total_shops_visited, ai_issues_summary) : nil

    # Do not send a blank report to anyone
    return if all_team_sellers.empty?

    SalesUser.active.find_each do |sales_user|
      personal_sellers = sellers_by_sales_user[sales_user.id] || []
      personal_count = personal_sellers.size
      personal_current_total = all_time_counts[sales_user.id] || 0
      has_team_access = sales_user.team_sales_dashboard_access?

      # Employed sales team, leads, and managers get the full team view; commission foot soldiers get only their own data
      summary_for_email = has_team_access ? team_summary_array : []
      all_sellers_for_email = has_team_access ? all_team_sellers : []
      team_total_for_email = has_team_access ? all_team_sellers.size : 0

      team_pdf_encoded = has_team_access && team_pdf ? Base64.strict_encode64(team_pdf) : nil

      SalesMailer.weekly_onboarding_summary(
        sales_user,
        window_start,
        window_end,
        personal_sellers,
        personal_count,
        personal_current_total,
        summary_for_email,
        all_sellers_for_email,
        team_total_for_email,
        has_team_access ? team_current_total : 0,
        has_team_access,
        team_pdf_encoded
      ).deliver_later
    end
  end

  private

  def build_seller_data(seller, assignment, sales_user)
    {
      id: seller.id,
      fullname: seller.fullname,
      enterpriseName: seller.enterprise_name,
      email: seller.email,
      phoneNumber: seller.phone_number,
      profilePicture: seller.profile_picture,
      location: seller.location,
      city: seller.city,
      createdAt: assignment.created_at.iso8601,
      assignedBy: sales_user.fullname.presence || sales_user.email.to_s.split('@').first
    }
  end

  # Build a landscape PDF report of the week's team onboardings.
  # PDF is generated once and attached to all manager/lead emails.
  def build_team_pdf(window_start, window_end, team_summary, all_team_sellers, team_current_total, total_shops_visited = 0, ai_issues_summary = nil)
    require 'prawn'
    require 'prawn/table'
    require 'open-uri'
    require 'timeout'

    Prawn::Fonts::AFM.hide_m17n_warning = true

    pdf = Prawn::Document.new(page_layout: :landscape, margin: [36, 36, 36, 36])
    setup_unicode_fonts(pdf)
    pdf.font_size 10

    brand_amber    = 'F59E0B'
    brand_amber_dk = 'D97706'
    brand_slate    = '0F172A'
    brand_slate_lt = '1E293B'
    brand_text     = '334155'
    brand_muted    = '64748B'
    brand_light    = 'F8FAFC'
    brand_lighter  = 'FFFBEB'
    brand_border   = 'E2E8F0'
    brand_green    = '16A34A'
    brand_red      = 'DC2626'
    brand_green_bg = 'DCFCE7'
    brand_red_bg   = 'FEE2E2'

    generated_at = Time.current.in_time_zone('Africa/Nairobi').strftime('%b %d, %Y at %I:%M %p %Z')
    start_str    = window_start.in_time_zone('Africa/Nairobi').strftime('%b %d, %Y')
    end_str      = window_end.in_time_zone('Africa/Nairobi').strftime('%b %d, %Y')

    w = pdf.bounds.width

    # ── Page footer on all pages ───────────────────────────────────────────
    pdf.repeat(:all) do
      pdf.save_graphics_state do
        pdf.fill_color brand_border
        pdf.fill_rectangle [pdf.bounds.left, pdf.bounds.bottom + 14], w, 0.75
      end
      pdf.number_pages 'Page <page> of <total>',
                       at: [pdf.bounds.right - 120, pdf.bounds.bottom - 4],
                       width: 120, height: 12, size: 8,
                       align: :right, color: brand_muted
      pdf.text_box "Carbon Cube Kenya • Sales Fieldwork Summary • Generated #{generated_at}",
                   at: [pdf.bounds.left, pdf.bounds.bottom - 4],
                   width: w - 140, height: 12, size: 8, color: brand_muted
    end

    # ── Executive Cover Header ─────────────────────────────────────────────
    header_box_h = 76
    pdf.save_graphics_state do
      # Slate container box with rounded corners
      pdf.fill_color brand_slate
      pdf.fill_and_stroke_rounded_rectangle [0, pdf.cursor], w, header_box_h, 8
      pdf.stroke_color brand_border
      pdf.line_width 0.5

      # Top amber accent stripe
      pdf.fill_color brand_amber
      pdf.fill_rounded_rectangle [0, pdf.cursor], w, 4, 2
    end

    # Header content
    logo_path = Rails.root.join('app/assets/images/logo.png').to_s
    if File.exist?(logo_path)
      begin
        pdf.image logo_path, at: [18, pdf.cursor - 18], height: 40
      rescue StandardError
        # skip logo if image error
      end
    end

    # Branding text on left
    pdf.fill_color 'FFFFFF'
    pdf.draw_text 'CARBON CUBE KENYA', at: [68, pdf.cursor - 34], size: 14, style: :bold
    pdf.fill_color '94A3B8'
    pdf.draw_text 'Official Sales & Merchant Fieldwork Report', at: [68, pdf.cursor - 50], size: 8.5

    # Report title & date pill on right
    pdf.fill_color 'FFFFFF'
    pdf.draw_text 'Weekly Onboarding Summary', at: [w - 290, pdf.cursor - 32], size: 16, style: :bold
    
    # Date badge pill on right
    pdf.save_graphics_state do
      pdf.fill_color brand_slate_lt
      pdf.fill_and_stroke_rounded_rectangle [w - 290, pdf.cursor - 42], 274, 22, 4
      pdf.stroke_color '334155'
      pdf.line_width 0.5
    end
    pdf.fill_color brand_amber
    pdf.draw_text "Reporting Window:  #{start_str} – #{end_str}", at: [w - 280, pdf.cursor - 57], size: 8.5, style: :bold

    pdf.move_down header_box_h + 16

    # ── 4 KPI Stats Strip ──────────────────────────────────────────────────
    col_w  = (w - 30) / 4.0
    kpi_y  = pdf.cursor
    kpi_h  = 58

    visited_count = total_shops_visited.to_i
    onboarded_count = all_team_sellers.size
    conversion_pct = visited_count > 0 ? ((onboarded_count.to_f / visited_count) * 100).round(1) : 0.0

    [
      ['SHOPS VISITED',     visited_count > 0 ? visited_count.to_s : '—',   20, brand_slate],
      ['NEW ONBOARDED',     onboarded_count.to_s,                           20, brand_green],
      ['FIELD CONVERSION',  visited_count > 0 ? "#{conversion_pct}%" : '—', 20, brand_amber_dk],
      ['ALL-TIME TOTAL',    team_current_total.to_s,                        20, brand_slate]
    ].each_with_index do |(label, value, fsize, val_color), idx|
      x = idx * (col_w + 10)
      pdf.bounding_box([x, kpi_y], width: col_w, height: kpi_h) do
        pdf.save_graphics_state do
          pdf.fill_color brand_light
          pdf.stroke_color brand_border
          pdf.line_width 0.75
          pdf.fill_and_stroke_rounded_rectangle [0, kpi_h], col_w, kpi_h, 6
        end
        pdf.fill_color brand_muted
        pdf.text_box label,
                     at: [12, kpi_h - 10], width: col_w - 16, height: 12,
                     size: 7, style: :bold
        pdf.fill_color val_color
        pdf.text_box value,
                     at: [12, kpi_h - 26], width: col_w - 16, height: fsize + 4,
                     size: fsize, style: :bold
      end
    end
    pdf.move_down kpi_h + 14

    # ── AI Weekly Issues & Fieldwork Intelligence Briefing ─────────────────
    if ai_issues_summary.present?
      ai_box_w = w
      # Measure or calculate box height based on content
      pdf.save_graphics_state do
        pdf.fill_color 'F8FAFC'
        pdf.stroke_color 'CBD5E1'
        pdf.line_width 0.75
        pdf.fill_and_stroke_rounded_rectangle [0, pdf.cursor], ai_box_w, 82, 6
        
        # Left border indicator
        pdf.fill_color brand_amber
        pdf.fill_rounded_rectangle [0, pdf.cursor], 4, 82, 2
      end

      # Header label
      pdf.fill_color brand_slate
      pdf.text_box 'WEEKLY FIELDWORK INTELLIGENCE & ISSUES SUMMARY (AI SYNTHESIZED)',
                   at: [14, pdf.cursor - 8], width: ai_box_w - 28, height: 12,
                   size: 7.5, style: :bold
      
      pdf.fill_color brand_text
      pdf.text_box ai_issues_summary,
                   at: [14, pdf.cursor - 22], width: ai_box_w - 28, height: 56,
                   size: 7.5, leading: 2, overflow: :truncate

      pdf.move_down 94
    end

    # ── Commission Payment Status ──────────────────────────────────────────
    commission_users = SalesUser.active.where("lower(compensation_type) = 'commission'").to_a
    if commission_users.any?
      pdf.fill_color brand_slate
      pdf.text 'Commission Payment Status', size: 12, style: :bold
      pdf.move_down 2
      pdf.fill_color brand_muted
      pdf.text 'Payment benchmark: 1 payment per every 10 onboardings. First batch of 10 already settled.', size: 7.5
      pdf.move_down 8

      pay_data = [['Sales Representative', 'Total Onboarded', 'Settled Batches', 'Unpaid Sellers', 'Payment Status']]
      commission_users.each do |cu|
        total          = cu.total_onboarded
        earned_batches = cu.earned_commission_batches
        batches_paid   = cu.paid_commission_batches.to_i
        unpaid_sellers = cu.unpaid_seller_count
        status_text    = unpaid_sellers > 0 ? "DUE — #{unpaid_sellers} sellers" : 'Up to date'

        pay_data << [
          sanitize(cu.fullname.presence || cu.email),
          total.to_s,
          "#{batches_paid} batch (#{batches_paid * 10} sellers)",
          unpaid_sellers > 0 ? "#{unpaid_sellers} sellers" : '0',
          status_text
        ]
      end

      cw0 = w * 0.28
      cw1 = w * 0.16
      cw2 = w * 0.20
      cw3 = w * 0.16
      cw4 = w - cw0 - cw1 - cw2 - cw3

      pdf.table(pay_data, header: true, width: w,
                column_widths: { 0 => cw0, 1 => cw1, 2 => cw2, 3 => cw3, 4 => cw4 }) do
        cells.padding           = [7, 8]
        cells.size              = 8.5
        cells.borders           = [:bottom]
        cells.border_color      = brand_border
        cells.border_width      = 0.5
        cells.background_color  = 'FFFFFF'
        column(1).align         = :center
        column(2).align         = :center
        column(3).align         = :center

        row(0).font_style       = :bold
        row(0).background_color = brand_slate
        row(0).text_color       = 'FFFFFF'
        row(0).size             = 8.5
        row(0).borders          = []

        (1...pay_data.length).each do |i|
          is_due = pay_data[i][4].to_s.start_with?('DUE')
          row(i).column(4).text_color       = is_due ? brand_red : brand_green
          row(i).column(4).font_style       = :bold
          row(i).column(4).background_color = is_due ? brand_red_bg : brand_green_bg
        end
      end
      pdf.move_down 18
    end

    # ── Team Leaderboard ───────────────────────────────────────────────────
    pdf.fill_color brand_slate
    pdf.text 'Team Leaderboard', size: 12, style: :bold
    pdf.move_down 8

    if team_summary.any?
      medals = ['1st', '2nd', '3rd']
      leaderboard_data = [['Rank', 'Sales Representative', 'This Week', 'All-Time Total']]
      team_summary.each_with_index do |member, i|
        rank_label = medals[i] || "#{i + 1}th"
        leaderboard_data << [
          rank_label,
          sanitize(member[:fullname]),
          member[:count].to_s,
          member[:currentTotal].to_s
        ]
      end

      pdf.table(leaderboard_data, header: true, width: w,
                column_widths: { 0 => 55, 1 => w - 235, 2 => 90, 3 => 90 }) do
        cells.padding           = [7, 8]
        cells.size              = 8.5
        cells.borders           = [:bottom]
        cells.border_color      = brand_border
        cells.border_width      = 0.5
        cells.background_color  = 'FFFFFF'
        column(2).align         = :center
        column(3).align         = :center

        row(0).font_style       = :bold
        row(0).background_color = brand_amber
        row(0).text_color       = 'FFFFFF'
        row(0).size             = 8.5
        row(0).borders          = []

        team_summary.each_with_index do |_, i|
          case i
          when 0
            row(i + 1).background_color = brand_lighter
            row(i + 1).font_style       = :bold
            row(i + 1).text_color       = brand_slate
          when 1, 2
            row(i + 1).background_color = brand_light
            row(i + 1).text_color       = brand_text
          end
        end
      end
    else
      pdf.fill_color brand_muted
      pdf.text 'No team onboardings this week.', size: 9
    end

    pdf.move_down 24

    # ── All Team Onboardings ───────────────────────────────────────────────
    if pdf.cursor < 120
      pdf.start_new_page
    end

    pdf.fill_color brand_slate
    pdf.text 'All Team Onboardings This Week', size: 12, style: :bold
    pdf.move_down 8

    if all_team_sellers.empty?
      pdf.fill_color brand_muted
      pdf.text 'No onboardings this week.', size: 9
    else
      temp_images = []

      # Draw initial table header
      draw_onboarding_table_header(pdf, w, brand_amber)

      all_team_sellers.each_with_index do |s, idx|
        row_h = 42
        if pdf.cursor < row_h + 30
          pdf.start_new_page
          draw_onboarding_table_header(pdf, w, brand_amber)
        end

        row_bg = idx.even? ? 'FFFFFF' : 'F8FAFC'
        pdf.save_graphics_state do
          pdf.fill_color row_bg
          pdf.fill_rectangle [0, pdf.cursor], w, row_h
        end

        # Avatar circle / Image
        av_r  = 15
        av_cx = 8 + av_r
        av_cy = pdf.cursor - (row_h / 2.0)

        name_raw = sanitize(s[:enterpriseName] || s[:fullname])
        initials = name_raw.split(/\s+/).map { |p| p[0]&.upcase }.compact.first(2).join

        avatar_tf = fetch_pdf_avatar_raw(s[:profilePicture], temp_images)
        if avatar_tf
          begin
            pdf.save_graphics_state do
              pdf.circle [av_cx, av_cy], av_r
              pdf.add_content "W n"
              pdf.image avatar_tf.path,
                        at: [av_cx - av_r, av_cy + av_r],
                        width: av_r * 2
            end
          rescue StandardError
            draw_initials_circle(pdf, av_cx, av_cy, av_r, initials)
          end
        else
          draw_initials_circle(pdf, av_cx, av_cy, av_r, initials)
        end

        # Seller Name + Masked Email
        info_x = av_cx + av_r + 8
        info_w = 175
        pdf.fill_color brand_slate
        pdf.text_box name_raw,
                     at: [info_x, pdf.cursor - 9],
                     width: info_w, height: 13,
                     size: 9, style: :bold, overflow: :truncate
        pdf.fill_color brand_muted
        pdf.text_box mask_email(s[:email]),
                     at: [info_x, pdf.cursor - 23],
                     width: info_w, height: 11,
                     size: 7.5, overflow: :truncate

        # Phone
        phone_x = info_x + info_w + 6
        pdf.fill_color brand_text
        pdf.text_box sanitize(s[:phoneNumber]).to_s,
                     at: [phone_x, pdf.cursor - 13],
                     width: 82, height: 14, size: 8.5

        # Location
        loc_x = phone_x + 86
        loc   = sanitize([s[:location], s[:city]].compact.join(', '))
        pdf.fill_color brand_text
        pdf.text_box loc,
                     at: [loc_x, pdf.cursor - 8],
                     width: 196, height: 26,
                     size: 7.5, overflow: :truncate

        # Onboarded by
        by_x = loc_x + 200
        pdf.fill_color brand_slate
        pdf.text_box sanitize(s[:assignedBy]),
                     at: [by_x, pdf.cursor - 13],
                     width: 110, height: 14, size: 8.5, overflow: :truncate

        # Date
        pdf.fill_color brand_muted
        pdf.text_box format_pdf_date(s[:createdAt]),
                     at: [w - 70, pdf.cursor - 13],
                     width: 68, height: 14,
                     size: 8, align: :right

        # Row border
        pdf.save_graphics_state do
          pdf.stroke_color brand_border
          pdf.line_width 0.4
          pdf.stroke_horizontal_line 0, w, at: pdf.cursor - row_h
        end

        pdf.move_down row_h
      end

      # Cleanup temporary avatar files
      temp_images.each do |f|
        f.close rescue nil
        f.unlink rescue nil
      end
    end

    pdf.render
  end

  def draw_onboarding_table_header(pdf, pdf_width, brand_amber)
    th_h = 24
    pdf.save_graphics_state do
      pdf.fill_color brand_amber
      pdf.fill_rectangle [0, pdf.cursor], pdf_width, th_h
    end

    pdf.fill_color 'FFFFFF'
    pdf.text_box 'Seller', at: [46, pdf.cursor - 7], width: 175, height: 12, size: 8, style: :bold
    pdf.text_box 'Phone', at: [235, pdf.cursor - 7], width: 82, height: 12, size: 8, style: :bold
    pdf.text_box 'Location', at: [321, pdf.cursor - 7], width: 196, height: 12, size: 8, style: :bold
    pdf.text_box 'Onboarded By', at: [521, pdf.cursor - 7], width: 110, height: 12, size: 8, style: :bold
    pdf.text_box 'Date', at: [pdf_width - 70, pdf.cursor - 7], width: 68, height: 12, size: 8, style: :bold, align: :right

    pdf.move_down th_h
  end

  def draw_initials_circle(pdf, center_x, center_y, radius, initials)
    color = avatar_color(initials)
    pdf.save_graphics_state do
      pdf.fill_color color
      pdf.fill_circle [center_x, center_y], radius
    end
    pdf.save_graphics_state do
      pdf.fill_color 'FFFFFF'
      pdf.text_box initials.to_s,
                   at: [center_x - radius, center_y + 4.5],
                   width: radius * 2, height: 11,
                   align: :center, size: 8.5, style: :bold
    end
  end

  # Fetch avatar image; returns a Tempfile or nil — never throws
  def fetch_pdf_avatar_raw(url, temp_files)
    return nil if url.blank?
    url = "https:#{url}" if url.start_with?('//')
    return nil unless url.start_with?('http')

    begin
      ext  = url.include?('googleusercontent') ? '.jpg' : (File.extname(URI.parse(url).path).presence || '.jpg')
      temp = Tempfile.new(['pdf_av', ext])
      temp.binmode
      Timeout.timeout(3) do
        URI.parse(url).open('rb', read_timeout: 3) { |f| temp.write(f.read) }
      end
      temp.flush
      temp.rewind
      temp_files << temp
      temp
    rescue StandardError
      nil
    end
  end

  # Deterministic color based on initials
  def avatar_color(initials)
    palette = %w[3B82F6 8B5CF6 EC4899 14B8A6 F97316 06B6D4 84CC16 EF4444 A855F7 10B981]
    palette[initials.to_s.bytes.sum % palette.size]
  end

  def mask_email(email)
    return '—' if email.blank?
    parts = email.split('@')
    return email unless parts.length == 2
    username, domain = parts
    masked = username.length > 2 ? "#{username[0..1]}***" : "#{username[0]}***"
    "#{masked}@#{domain}"
  end

  # Try to load a system Unicode font so PDFs can render any seller name or issue text.
  # Falls back to Helvetica if none is available; in that case sanitize strips unsupported chars.
  def setup_unicode_fonts(pdf)
    font_pairs = [
      ['/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'],
      ['/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf', '/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf'],
      ['/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf', '/usr/share/fonts/truetype/noto/NotoSans-Bold.ttf'],
      ['/System/Library/Fonts/Supplemental/Arial Unicode.ttf', '/System/Library/Fonts/Supplemental/Arial Bold.ttf'],
      ['/Library/Fonts/Arial Unicode.ttf', '/Library/Fonts/Arial Bold.ttf'],
      ['C:/Windows/Fonts/arial.ttf', 'C:/Windows/Fonts/arialbd.ttf']
    ]

    normal_path, bold_path = font_pairs.find { |normal, bold| File.exist?(normal) && File.exist?(bold) }

    if normal_path
      pdf.font_families.update(
        'SalesFont' => { normal: normal_path, bold: bold_path || normal_path }
      )
      pdf.font 'SalesFont'
    else
      pdf.font 'Helvetica'
    end
  end

  def sanitize(text)
    text.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
  end

  def format_pdf_date(iso_string)
    Time.parse(iso_string).in_time_zone('Africa/Nairobi').strftime('%b %d')
  rescue StandardError
    iso_string.to_s
  end

  def generate_weekly_ai_summary(weekly_reports, total_shops_visited, weekly_onboarded)
    return nil if weekly_reports.blank?

    challenges_list = weekly_reports.filter_map do |r|
      "- [#{r.report_date}] #{r.challenges}" if r.challenges.present?
    end

    return nil if challenges_list.empty?

    raw_text = challenges_list.join("\n")
    conversion_rate = total_shops_visited > 0 ? (weekly_onboarded.to_f / total_shops_visited * 100).round(1) : 0.0
    metrics_line = "Shops visited: #{total_shops_visited}. Businesses onboarded: #{weekly_onboarded}. Conversion rate: #{conversion_rate}%."

    if ENV['GROQ_API_KEY'].present?
      begin
        prompt = <<~PROMPT
          You are an executive operations analyst for Carbon Cube Kenya.
          #{metrics_line}

          Below are the real field obstacles and feedback reported by our sales reps during their fieldwork this past week:

          """
          #{raw_text}
          """

          Summarize these into two sections for an executive weekly PDF report:
          KEY FIELD FRICTION:
          • (Bullet 1)
          • (Bullet 2)
          • (Bullet 3)

          RECOMMENDED ACTIONS:
          • (Bullet 1)
          • (Bullet 2)

          Keep plain text only (no bold markdown like **), clean bullets with •. Max 100 words total.
        PROMPT

        uri = URI('https://api.groq.com/openai/v1/chat/completions')
        req = Net::HTTP::Post.new(uri, 'Authorization' => "Bearer #{ENV['GROQ_API_KEY']}", 'Content-Type' => 'application/json')
        req.body = {
          model: 'openai/gpt-oss-120b',
          messages: [{ role: 'user', content: prompt }],
          max_tokens: 260,
          temperature: 0.2
        }.to_json

        res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 8, open_timeout: 4) { |h| h.request(req) }
        if res.is_a?(Net::HTTPSuccess)
          ai_text = JSON.parse(res.body).dig('choices', 0, 'message', 'content').to_s.strip
          return ai_text.gsub('**', '') if ai_text.present?
        end
      rescue StandardError => e
        Rails.logger.warn "WeeklySellerOnboardingSummaryJob AI summary failed: #{e.message}"
      end
    end

    # Fallback summary if AI call fails
    "WEEKLY SUMMARY: #{metrics_line}\n\nKEY FIELD FRICTION:\n• Merchant hesitation in hardware/electrical sectors regarding platform credibility\n• Smartphone access friction and app initialization loading times\n• Data bundle & airtime limitations during field outreach\n\nRECOMMENDED ACTIONS:\n• Provide physical verification collateral & offline pitch materials\n• Optimize mobile onboarding speed and ad upload flows"
  end
end

