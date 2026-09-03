# frozen_string_literal: true

class CreateReviewPrompts < ActiveRecord::Migration[7.1]
  def change
    create_table :review_prompts do |t|
      t.references :buyer, null: false, foreign_key: true, type: :uuid
      t.references :ad, null: false, foreign_key: true, type: :bigint
      t.references :click_event, null: true, foreign_key: true, type: :bigint
      t.string :status, null: false, default: 'pending'
      t.string :channel, null: false, default: 'email'
      t.datetime :scheduled_at
      t.datetime :sent_at
      t.datetime :opened_at
      t.datetime :completed_at
      t.integer :reminders_count, null: false, default: 0

      t.timestamps
    end

    add_index :review_prompts, %i[buyer_id ad_id], unique: true
    add_index :review_prompts, :status
    add_index :review_prompts, :scheduled_at
    add_index :review_prompts, :reminders_count
  end
end
