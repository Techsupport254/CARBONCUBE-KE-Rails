class CreateOutreachProspects < ActiveRecord::Migration[7.1]
  def change
    create_table :outreach_prospects do |t|
      t.string :business_name, null: false
      t.string :email
      t.string :phone
      t.string :area
      t.string :category
      t.string :subcategory
      t.string :website
      t.string :source_url
      t.string :source_type
      t.string :list_type, default: 'main'
      t.string :status, null: false, default: 'pending'
      t.datetime :sent_at
      t.string :message_id
      t.text :error
      t.timestamps
    end

    add_index :outreach_prospects, :status
    add_index :outreach_prospects, 'lower(email)', unique: true,
              name: 'index_outreach_prospects_on_lower_email'
    add_index :outreach_prospects, 'lower(business_name)',
              name: 'index_outreach_prospects_on_lower_business_name'
  end
end
