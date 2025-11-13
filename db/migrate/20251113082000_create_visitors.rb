class CreateVisitors < ActiveRecord::Migration[7.1]
  def change
    create_table :visitors, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :visitor_id, null: false, index: { unique: true }
      t.string :device_fingerprint_hash, index: true
      t.string :first_source
      t.string :first_referrer
      t.string :first_utm_source
      t.string :first_utm_medium
      t.string :first_utm_campaign
      t.string :first_utm_content
      t.string :first_utm_term
      t.string :ip_address
      t.string :country
      t.string :city
      t.string :region
      t.string :timezone
      t.jsonb :device_info, default: {}
      t.string :user_agent
      t.datetime :first_visit_at, null: false
      t.datetime :last_visit_at, null: false
      t.integer :visit_count, default: 1, null: false
      t.boolean :has_clicked_ad, default: false
      t.datetime :first_ad_click_at
      t.datetime :last_ad_click_at
      t.integer :ad_click_count, default: 0
      t.boolean :is_internal_user, default: false
      t.uuid :registered_user_id
      t.string :registered_user_type
      t.timestamps

      t.index [:ip_address]
      t.index [:first_source]
      t.index [:first_visit_at]
      t.index [:last_visit_at]
      t.index [:is_internal_user]
      t.index [:has_clicked_ad]
      t.index [:registered_user_id, :registered_user_type]
    end
  end
end
