class BackfillEmailVerifiedFor2026Sellers < ActiveRecord::Migration[7.1]
  def up
    # Mark email_otps as verified for all 2026 sellers (they completed OTP during signup)
    sql = <<-SQL.squish
      UPDATE email_otps
      SET verified = true
      WHERE verified = false
      AND email IN (
        SELECT email FROM sellers WHERE EXTRACT(YEAR FROM created_at) = 2026
      )
    SQL
    result = execute(sql)
    count = result.respond_to?(:cmd_tuples) ? result.cmd_tuples : 0
    Rails.logger.info "✅ Backfilled email verification for #{count} 2026 seller(s)" if count && count > 0
  end

  def down
    # No rollback - we don't unverify emails
  end
end
