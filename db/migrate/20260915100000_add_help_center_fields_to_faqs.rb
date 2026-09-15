class AddHelpCenterFieldsToFaqs < ActiveRecord::Migration[7.1]
  def change
    change_table :faqs, bulk: true do |t|
      t.string :category, null: false, default: "general"
      t.integer :position, null: false, default: 0
      t.integer :helpful_count, null: false, default: 0
      t.integer :not_helpful_count, null: false, default: 0

      t.index :category
    end
  end
end
