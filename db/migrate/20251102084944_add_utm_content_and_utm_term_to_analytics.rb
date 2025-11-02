class AddUtmContentAndUtmTermToAnalytics < ActiveRecord::Migration[7.1]
  def change
    add_column :analytics, :utm_content, :string
    add_column :analytics, :utm_term, :string
  end
end
