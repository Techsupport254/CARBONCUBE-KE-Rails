class AddIndexesToAnalyticsForPerformance < ActiveRecord::Migration[7.1]
  def change
    add_index :analytics, :created_at, if_not_exists: true
    add_index :analytics, :source, if_not_exists: true
    add_index :analytics, :utm_source, if_not_exists: true
    add_index :analytics, :utm_medium, if_not_exists: true
    add_index :analytics, :utm_campaign, if_not_exists: true
    add_index :analytics, :utm_content, if_not_exists: true
    add_index :analytics, :utm_term, if_not_exists: true
    add_index :analytics, :referrer, if_not_exists: true

    unless index_exists?(:analytics, "(data->>'visitor_id')", name: "index_analytics_on_visitor_id")
      execute "CREATE INDEX IF NOT EXISTS index_analytics_on_visitor_id ON analytics ((data->>'visitor_id'));"
    end

    unless index_exists?(:analytics, "(data->>'user_email')", name: "index_analytics_on_user_email")
      execute "CREATE INDEX IF NOT EXISTS index_analytics_on_user_email ON analytics ((data->>'user_email'));"
    end
  end
end
