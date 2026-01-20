class CreateSearchAnalytics < ActiveRecord::Migration[7.1]
  def change
    unless table_exists?(:search_analytics)
      create_table :search_analytics do |t|
        t.date :date, null: false
        t.integer :total_searches_today, default: 0
        t.integer :unique_search_terms_today, default: 0
        t.integer :total_search_records, default: 0
        t.text :popular_searches_all_time
        t.text :popular_searches_daily
        t.text :popular_searches_weekly
        t.text :popular_searches_monthly
        t.jsonb :raw_analytics_data

        t.timestamps
      end

      add_index :search_analytics, :date, unique: true
    end
  end
end
