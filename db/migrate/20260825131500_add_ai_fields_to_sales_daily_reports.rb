class AddAiFieldsToSalesDailyReports < ActiveRecord::Migration[7.1]
  def change
    add_column :sales_daily_reports, :categories, :string, array: true, default: []
    add_column :sales_daily_reports, :ai_summary, :text
    add_column :sales_daily_reports, :sentiment, :string
    add_column :sales_daily_reports, :urgency, :string
    add_column :sales_daily_reports, :action_items, :string, array: true, default: []

    add_index :sales_daily_reports, :categories, using: 'gin'
  end
end
