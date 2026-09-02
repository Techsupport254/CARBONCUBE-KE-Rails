class SeedCommissionPayoutBatches < ActiveRecord::Migration[7.1]
  def up
    SalesUser.where("LOWER(compensation_type) = 'commission'").find_each do |user|
      next if user.paid_commission_batches.to_i.positive?

      total = SellerCarbonCodeAssignment.where(sales_user_id: user.id).count
      next if total < 10

      user.update!(paid_commission_batches: 1, last_commission_paid_at: Time.current)
    end
  end

  def down
    SalesUser.where("LOWER(compensation_type) = 'commission'").update_all(paid_commission_batches: 0, last_commission_paid_at: nil)
  end
end
