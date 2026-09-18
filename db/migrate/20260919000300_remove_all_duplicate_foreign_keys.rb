# frozen_string_literal: true

# Follow-up to RemoveDuplicateForeignKeys: the same double-add bug left
# identical FK constraints on 14 more table/column pairs (cart_items,
# click_events, conversations, issues, offers, payment_transactions, reviews,
# seller_documents, seller_tiers, wish_lists). Generated constraint names
# differ per database, so scan every table for FK groups that are identical
# in target table, column and delete/update behaviour and drop all but one.
class RemoveAllDuplicateForeignKeys < ActiveRecord::Migration[7.1]
  def up
    duplicate_foreign_keys.each do |fk|
      remove_foreign_key fk.from_table, name: fk.name
    end
  end

  def down
    # Irreversible by design: the removed constraints were exact copies of
    # ones that remain, so there is nothing meaningful to restore.
  end

  private

  def duplicate_foreign_keys
    connection.tables.flat_map do |table|
      connection.foreign_keys(table)
        .group_by { |fk| [fk.to_table, fk.column.to_s, fk.options[:on_delete], fk.options[:on_update]] }
        .values
        .select { |group| group.size > 1 }
        .flat_map { |group| group.drop(1) }
    end
  end
end
