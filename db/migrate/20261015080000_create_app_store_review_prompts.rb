class CreateAppStoreReviewPrompts < ActiveRecord::Migration[7.1]
  def change
    create_table :app_store_review_prompts do |t|
      t.references :user, polymorphic: true, type: :uuid, null: false, index: { unique: true, name: 'index_app_store_review_prompts_on_user' }
      t.string  :status,       null: false, default: 'pending'
      t.datetime :scheduled_at, null: false
      t.datetime :shown_at

      t.timestamps
    end

    add_index :app_store_review_prompts, :status
    add_index :app_store_review_prompts, :scheduled_at
  end
end
