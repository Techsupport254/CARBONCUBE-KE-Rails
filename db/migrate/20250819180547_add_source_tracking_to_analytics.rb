class AddSourceTrackingToAnalytics < ActiveRecord::Migration[8.0]
  def change
    add_column :analytics, :source, :string
    add_column :analytics, :referrer, :string
    add_column :analytics, :utm_source, :string
    add_column :analytics, :utm_medium, :string
    add_column :analytics, :utm_campaign, :string
    add_column :analytics, :user_agent, :text
    add_column :analytics, :ip_address, :string
  end
end
