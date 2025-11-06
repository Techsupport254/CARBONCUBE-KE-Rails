# config/sitemap.rb
SitemapGenerator::Sitemap.default_host = "https://carboncube-ke.com/"
SitemapGenerator::Sitemap.public_path = 'public/'
SitemapGenerator::Sitemap.sitemaps_path = 'sitemaps/'
SitemapGenerator::Sitemap.compress = true

# Ensure all URLs use HTTPS and canonical format
SitemapGenerator::Sitemap.adapter = SitemapGenerator::FileAdapter.new
SitemapGenerator::Sitemap.include_root = false
SitemapGenerator::Sitemap.include_index = false

SitemapGenerator::Sitemap.create do
  # Homepage (highest priority)
  add root_path, priority: 1.0, changefreq: 'daily'

  # Health check (low priority)
  add '/up', priority: 0.1, changefreq: 'monthly'

  # Public data endpoints
  add '/banners', priority: 0.5, changefreq: 'weekly'
  add '/counties', priority: 0.4, changefreq: 'monthly'
  add '/sectors', priority: 0.4, changefreq: 'monthly'
  add '/age_groups', priority: 0.3, changefreq: 'monthly'
  add '/educations', priority: 0.3, changefreq: 'monthly'
  add '/employments', priority: 0.3, changefreq: 'monthly'
  add '/incomes', priority: 0.3, changefreq: 'monthly'
  add '/tiers', priority: 0.4, changefreq: 'monthly'
  add '/document_types', priority: 0.3, changefreq: 'monthly'

  # Main ads listing (very high priority)
  add '/ads', priority: 0.9, changefreq: 'hourly'

  # Individual ads (dynamic from database)
  if defined?(Ad)
    # Assuming you have an Ad model with published/active scope
    # Adjust the scope based on your actual model
    ads_scope = Ad.respond_to?(:published) ? Ad.published : Ad.all
    ads_scope.find_each do |ad|
      add "/ads/#{ad.id}", 
          priority: 0.8, 
          changefreq: 'daily',
          lastmod: ad.updated_at
      
      # Ad reviews if they exist
      if ad.respond_to?(:reviews) && ad.reviews.any?
        add "/ads/#{ad.id}/reviews", 
            priority: 0.6, 
            changefreq: 'weekly',
            lastmod: ad.reviews.maximum(:updated_at)
      end
    end
  end

  # Seller ad pages (dynamic from database)
  if defined?(Seller)
    sellers_scope = Seller.respond_to?(:active) ? Seller.active : Seller.all
    sellers_scope.find_each do |seller|
      add "/sellers/#{seller.id}/ads", 
          priority: 0.7, 
          changefreq: 'daily',
          lastmod: seller.updated_at
    end
  end

  # Counties with sub-counties (dynamic from database)
  if defined?(County)
    County.find_each do |county|
      add "/counties/#{county.id}/sub_counties", 
          priority: 0.4, 
          changefreq: 'monthly'
    end
  end

  # Buyer interface pages
  add '/buyer/ads', priority: 0.9, changefreq: 'daily'
  add '/buyer/ads/search', priority: 0.8, changefreq: 'daily'
  add '/buyer/categories', priority: 0.8, changefreq: 'weekly'
  add '/buyer/subcategories', priority: 0.7, changefreq: 'weekly'

  # Individual buyer ad pages with related content
  if defined?(Ad)
    ads_scope = Ad.respond_to?(:published) ? Ad.published : Ad.all
    ads_scope.find_each do |ad|
      add "/buyer/ads/#{ad.id}", 
          priority: 0.8, 
          changefreq: 'daily',
          lastmod: ad.updated_at
      
      add "/buyer/ads/#{ad.id}/related", 
          priority: 0.6, 
          changefreq: 'daily'
      
      add "/buyer/ads/#{ad.id}/seller", 
          priority: 0.6, 
          changefreq: 'weekly'
    end
  end

  # Seller interface pages (public parts)
  add '/seller/categories', priority: 0.7, changefreq: 'weekly'
  add '/seller/subcategories', priority: 0.6, changefreq: 'weekly'

  # Categories (if you have a Category model)
  if defined?(Category)
    Category.includes(:subcategories).find_each do |category|
      # Generate slug from category name
      category_slug = if category.name.present?
        category.name.downcase
                  .gsub(/[^a-z0-9\s-]/, '')
                  .gsub(/\s+/, '-')
                  .gsub(/-+/, '-')
                  .gsub(/^-|-$/, '')
      else
        "category-#{category.id}"
      end
      
      # Add category page
      add "/categories/#{category_slug}", 
          priority: 0.8, 
          changefreq: 'weekly',
          lastmod: category.updated_at
      
      # Add subcategory pages with correct format: /categories/{category-slug}/{subcategory-slug}
      category.subcategories.each do |subcategory|
        subcategory_slug = if subcategory.name.present?
          subcategory.name.downcase
                    .gsub(/[^a-z0-9\s-]/, '')
                    .gsub(/\s+/, '-')
                    .gsub(/-+/, '-')
                    .gsub(/^-|-$/, '')
        else
          "subcategory-#{subcategory.id}"
        end
        add "/categories/#{category_slug}/#{subcategory_slug}", 
            priority: 0.7, 
            changefreq: 'weekly',
            lastmod: subcategory.updated_at
      end
    end
  end
end