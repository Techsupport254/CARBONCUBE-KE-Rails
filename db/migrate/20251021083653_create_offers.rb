class CreateOffers < ActiveRecord::Migration[7.1]
  def change
    create_table :offers do |t|
      # Basic offer information
      t.string :name, null: false
      t.text :description
      t.string :offer_type, null: false
      t.string :status, default: 'draft'
      
      # Visual and branding
      t.string :banner_color, default: '#dc2626'
      t.string :badge_color, default: '#fbbf24'
      t.string :icon_name
      t.text :banner_image_url
      t.text :hero_image_url
      
      # Timing and scheduling
      t.datetime :start_time
      t.datetime :end_time
      t.boolean :is_recurring, default: false
      t.string :recurrence_pattern
      t.json :recurrence_config
      
      # Discount configuration
      t.decimal :discount_percentage, precision: 5, scale: 2
      t.decimal :fixed_discount_amount, precision: 10, scale: 2
      t.string :discount_type
      t.json :discount_config
      
      # Targeting and eligibility
      t.json :target_categories
      t.json :target_sellers
      t.json :target_products
      t.string :eligibility_criteria
      t.decimal :minimum_order_amount, precision: 10, scale: 2
      t.integer :max_uses_per_customer
      t.integer :total_usage_limit
      
      # Display and UX
      t.integer :priority, default: 0
      t.boolean :featured, default: false
      t.boolean :show_on_homepage, default: true
      t.boolean :show_badge, default: true
      t.string :badge_text, default: 'SALE'
      t.text :cta_text, default: 'Shop Now'
      t.text :terms_and_conditions
      
      # Analytics and tracking
      t.integer :view_count, default: 0
      t.integer :click_count, default: 0
      t.integer :conversion_count, default: 0
      t.decimal :revenue_generated, precision: 12, scale: 2, default: 0.0
      
      # Seller reference
      t.integer :seller_id, null: false
      
      t.timestamps
    end
    
    add_index :offers, :seller_id
    add_index :offers, :offer_type
    add_index :offers, :status
    add_index :offers, :start_time
    add_index :offers, :end_time
    add_index :offers, :featured
    add_index :offers, :priority
    add_index :offers, [:status, :start_time, :end_time]
  end
end