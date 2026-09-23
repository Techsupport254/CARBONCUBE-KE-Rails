# frozen_string_literal: true

class CreateSearchSynonyms < ActiveRecord::Migration[7.1]
  def change
    create_table :search_synonyms do |t|
      t.string :term, null: false
      t.string :synonym, null: false

      t.timestamps
    end

    add_index :search_synonyms, [:term, :synonym], unique: true
    add_index :search_synonyms, :term
  end
end
