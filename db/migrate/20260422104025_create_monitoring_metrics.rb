class CreateMonitoringMetrics < ActiveRecord::Migration[7.1]
  def change
    create_table :monitoring_metrics do |t|
      t.string :name
      t.decimal :value
      t.datetime :timestamp
      t.json :tags

      t.timestamps
    end
  end
end
