namespace :black_friday do
  desc <<~DESC
    Tag ~100 moving ads as Black November anchor deals.

    Selection: Ad.live minus service categories, bottom 60% price
    within each category, engagement
    score (conversations*4 + wishlists*2 + reviews*2 + quality score),
    best ad per seller, round-robin across categories until TARGET ads.

    Anchor: offer_ads.original_price is set to min(price * MAX_UPLIFT,
    market P75 of same-subcategory listings) and discounted_price to the
    ad's REAL price — the displayed "was" price is inflated but the
    transaction price never changes. Ads on active offers are skipped —
    previously-offered ads stay out of the Black November set entirely.

    Ads whose market reference leaves less than MIN_UPLIFT headroom are
    skipped so the anchor stays believable.

    Dry-run by default; COMMIT=1 writes. Knobs: TARGET, PRICE_PCT,
    MARKET_PCT, MIN_UPLIFT, MAX_UPLIFT, CAMPAIGN_END.
  DESC
  task tag_ads: :environment do
    commit = ENV["COMMIT"] == "1"
    target = (ENV["TARGET"] || 100).to_i
    price_pct = ((ENV["PRICE_PCT"] || 60).to_f / 100).clamp(0.05, 1.0)
    market_pct = ((ENV["MARKET_PCT"] || 75).to_f / 100).clamp(0.5, 1.0)
    min_uplift = (ENV["MIN_UPLIFT"] || 10).to_f / 100
    max_uplift = (ENV["MAX_UPLIFT"] || 25).to_f / 100
    campaign_end = Time.zone.parse(ENV["CAMPAIGN_END"] || "2026-11-30 23:59:59")
    now = Time.current

    percentile = lambda do |sorted, pct|
      next nil if sorted.empty?

      sorted[((sorted.length - 1) * pct).round]
    end

    believable = lambda do |amount|
      step =
        case amount
        when 0...1_000 then 10
        when 1_000...10_000 then 50
        when 10_000...100_000 then 100
        else 500
        end
      (amount / step).round * step
    end

    # Ads ever attached to an offer — excluded from the Black November
    # set entirely; only never-offered ads get anchored.
    covered_ad_ids = OfferAd.distinct.pluck(:ad_id)

    service_patterns = Ad::SERVICE_CATEGORY_NAMES.map { |n| "%#{n}%" }
    pool = Ad.live.joins(:category)
      .where.not(price: [nil, 0]).where.not(seller_id: nil)
      .where("stock_quantity IS NULL OR stock_quantity > 0")
      .where.not(id: covered_ad_ids)
      .where.not("categories.name ILIKE ANY (array[?])", service_patterns)
      .pluck(:id, :seller_id, :category_id, :subcategory_id, :price,
        :reviews_count, :organic_quality_score, :title)

    puts "Eligible pool: #{pool.size} live ads (excluding #{covered_ad_ids.size} already on offers)"

    # Category-relative price cap: keep the bottom PRICE_PCT of each category.
    by_category = pool.group_by { |row| row[2] }
    price_caps = by_category.transform_values do |rows|
      percentile.call(rows.map { |r| r[4].to_f }.sort, price_pct)
    end
    priced = pool.select { |row| row[4].to_f <= price_caps[row[2]].to_f }
    puts "Under #{price_pct * 100}% category price cap: #{priced.size} ads"

    # Market reference price: MARKET_PCT of same-subcategory eligible ads.
    by_subcategory = priced.group_by { |row| row[3] }
    market_highs = {}
    by_subcategory.each do |sub_id, rows|
      market_highs[sub_id] = percentile.call(
        rows.map { |r| r[4].to_f }.sort, market_pct
      )
    end
    category_market_highs = by_category.transform_values do |rows|
      prices = rows.map { |r| r[4].to_f }.sort
      percentile.call(prices, market_pct)
    end

    # Engagement score: conversations + wishlists + reviews + quality.
    priced_ids = priced.map { |row| row[0] }
    conv_counts = Conversation.where(ad_id: priced_ids).group(:ad_id).count
    wish_counts = WishList.where(ad_id: priced_ids).group(:ad_id).count
    scored = priced.map do |row|
      id, seller_id, category_id, _sub_id, price, reviews, quality, title = row
      score =
        (conv_counts[id] || 0) * 4 +
        (wish_counts[id] || 0) * 2 +
        (reviews || 0) * 2 +
        (quality || 0)
      { id:, seller_id:, category_id:, subcategory_id: row[3],
        price: price.to_f, title:, score: }
    end

    # Best ad per seller, then round-robin categories until TARGET.
    best_per_seller = scored.group_by { |a| a[:seller_id] }
      .map { |_sid, ads| ads.max_by { |a| a[:score] } }
    queues = best_per_seller.group_by { |a| a[:category_id] }
      .transform_values { |ads| ads.sort_by { |a| -a[:score] } }
    selected = []
    until selected.size >= target || queues.values.all?(&:empty?)
      queues.keys.sort_by { |cid| -queues[cid].size }.each do |cid|
        selected << queues[cid].shift if queues[cid].any?
        break if selected.size >= target
      end
    end

    puts "-" * 96
    puts "AD       SELLER   CATEGORY               TITLE                                         PRICE     ANCHOR    OFF"
    puts "-" * 96

    tagged = 0
    skipped = []
    selected.each do |ad|
      market_high =
        market_highs[ad[:subcategory_id]] ||
        category_market_highs[ad[:category_id]]
      anchor = [ad[:price] * (1 + max_uplift), market_high || Float::INFINITY].min
      if anchor < ad[:price] * (1 + min_uplift)
        skipped << [ad, "no headroom"]
        next
      end
      anchor = believable.call(anchor)
      pct_off = ((anchor - ad[:price]) / anchor * 100).round(1)
      puts format("%<id>-8d %<seller>-8s %<category>-22s %<title>-40s " \
                  "%<price>10.0f %<anchor>10.0f %<pct>5.1f%%",
        id: ad[:id], seller: ad[:seller_id].to_s[0, 8],
        category: ad[:category_id].to_s, title: ad[:title].to_s[0, 38],
        price: ad[:price], anchor: anchor, pct: pct_off)

      if commit
        offer = Offer.where(seller_id: ad[:seller_id],
          offer_type: "black_friday").where("end_time >= ?", now).first ||
          Offer.create_black_friday_offer(
            seller_id: ad[:seller_id],
            name: "Black November Deals",
            description: "Black November special prices",
            status: "active",
            start_time: now,
            end_time: campaign_end,
            badge_text: "BLACK FRIDAY",
            show_on_homepage: true
          )
        offer_ad = OfferAd.find_or_initialize_by(
          offer_id: offer.id, ad_id: ad[:id]
        )
        offer_ad.original_price = anchor
        offer_ad.discounted_price = ad[:price]
        offer_ad.discount_percentage = nil # derived by model callback
        offer_ad.is_active = true
        offer_ad.seller_notes ||= "Black November anchor (ops-tagged)"
        offer_ad.save!
      end
      tagged += 1
    end

    puts "-" * 96
    puts "#{commit ? 'Tagged' : 'Would tag'} #{tagged} ads " \
         "(#{selected.map { |a| a[:seller_id] }.uniq.size} sellers, " \
         "#{selected.map { |a| a[:category_id] }.uniq.size} categories)"
    puts "Skipped #{skipped.size} (no believable headroom)" if skipped.any?
    puts "DRY RUN — rerun with COMMIT=1 to write" unless commit
  end
end
