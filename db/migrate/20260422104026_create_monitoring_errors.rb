class CreateMonitoringErrors < ActiveRecord::Migration[7.1]
  def change
    create_table :monitoring_errors do |t|
      t.string :message
      t.text :stack_trace
      t.string :level
      t.json :context
      t.datetime :resolved_at

      t.timestamps
    end
  end
end
