# frozen_string_literal: true

# The DB ended up with two identical foreign key constraints on
# ad_searches.buyer_id and ads.seller_id (each pair has the same target and
# on_delete behaviour, differing only by generated name). schema.rb therefore
# emitted the add_foreign_key lines twice and db:schema:load crashed with
# PG::DuplicateObject. Drop one of each duplicate; the remaining constraint
# keeps identical enforcement.
class RemoveDuplicateForeignKeys < ActiveRecord::Migration[7.1]
  DUPLICATE_FKS = [
    { table: :ad_searches, name: 'fk_rails_a8334c841e', to_table: :buyers, column: :buyer_id },
    { table: :ads, name: 'fk_rails_5a56c68991', to_table: :sellers, column: :seller_id }
  ].freeze

  def up
    DUPLICATE_FKS.each do |fk|
      next unless connection.foreign_keys(fk[:table]).any? { |key| key.name == fk[:name] }

      remove_foreign_key fk[:table], name: fk[:name]
    end
  end

  def down
    DUPLICATE_FKS.each do |fk|
      next if connection.foreign_keys(fk[:table]).any? { |key| key.name == fk[:name] }

      add_foreign_key fk[:table], fk[:to_table], column: fk[:column], on_delete: :cascade, name: fk[:name]
    end
  end
end
