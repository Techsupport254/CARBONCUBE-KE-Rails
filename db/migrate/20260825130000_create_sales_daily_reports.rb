class CreateSalesDailyReports < ActiveRecord::Migration[7.1]
  def change
    create_table :sales_daily_reports, id: :uuid do |t|
      t.references :sales_user, foreign_key: { to_table: :sales_users }, type: :uuid, null: false
      t.date :report_date, null: false
      t.string :route_areas, null: false
      t.integer :businesses_visited, default: 0, null: false
      t.integer :businesses_onboarded, default: 0, null: false
      t.text :challenges
      t.text :notes
      t.boolean :verified_by_manager, default: false

      t.timestamps
    end

    add_index :sales_daily_reports, [:sales_user_id, :report_date], unique: true, name: 'idx_sales_daily_reports_user_date'
    add_index :sales_daily_reports, :report_date
  end
end
