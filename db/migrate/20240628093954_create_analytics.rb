class CreateAnalytics < ActiveRecord::Migration[7.1]
  def change
    create_table :analytics do |t|
      t.string :type
      t.jsonb :data

      t.timestamps
    end
  end
end
