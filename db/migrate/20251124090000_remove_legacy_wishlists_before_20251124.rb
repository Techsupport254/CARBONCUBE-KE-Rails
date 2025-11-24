class RemoveLegacyWishlistsBefore20251124 < ActiveRecord::Migration[7.1]
  def up
    cutoff = Time.new(2025, 11, 24).end_of_day

    say_with_time "Removing wishlists created on or before #{cutoff.iso8601}" do
      execute <<~SQL.squish
        DELETE FROM wish_lists
        WHERE created_at <= '#{cutoff.utc}'
      SQL
    end
  end

  def down
    say "Data removal is irreversible; no rollback provided.", true
  end
end
