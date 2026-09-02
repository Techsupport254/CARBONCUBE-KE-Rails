# frozen_string_literal: true

class AddBuyerPerformanceIndexes < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    # Indexes that cover the filters and sorting used on /admin/buyers
    add_index :buyers, :created_at,
              algorithm: :concurrently,
              if_not_exists: true
    add_index :buyers, %i[deleted last_active_at],
              name: "index_buyers_on_deleted_last_active_at",
              algorithm: :concurrently,
              if_not_exists: true
    add_index :buyers, %i[deleted blocked last_active_at],
              name: "index_buyers_on_deleted_blocked_last_active_at",
              algorithm: :concurrently,
              if_not_exists: true

    # GIN trigram indexes for the ILIKE search across buyer fields.
    # These allow Postgres to use the index for leading-wildcard searches.
    add_index :buyers, :fullname,
              using: :gin,
              opclass: :gin_trgm_ops,
              algorithm: :concurrently,
              if_not_exists: true
    add_index :buyers, :username,
              using: :gin,
              opclass: :gin_trgm_ops,
              algorithm: :concurrently,
              if_not_exists: true
    add_index :buyers, :email,
              using: :gin,
              opclass: :gin_trgm_ops,
              algorithm: :concurrently,
              if_not_exists: true
    add_index :buyers, :phone_number,
              using: :gin,
              opclass: :gin_trgm_ops,
              algorithm: :concurrently,
              if_not_exists: true
    add_index :buyers, :location,
              using: :gin,
              opclass: :gin_trgm_ops,
              algorithm: :concurrently,
              if_not_exists: true
  end
end
