class PaymentVerificationService
  def self.verify_manual_payment(seller_id, transaction_id, amount)
    seller = Seller.find_by(id: seller_id)
    return { success: false, error: "Seller not found" } unless seller

    # Check if payment already exists
    existing_payment = Payment.find_by(trans_id: transaction_id)
    if existing_payment
      return { 
        success: true, 
        message: "Payment already processed",
        payment: existing_payment,
        tier_activated: true
      }
    end

    # Find matching tier pricing
    tier_pricing = TierPricing.find_by(price: amount)
    unless tier_pricing
      return { 
        success: false, 
        error: "No tier pricing found for amount #{amount}" 
      }
    end

    # Create a pending payment transaction for verification
    payment_transaction = PaymentTransaction.create!(
      seller_id: seller.id,
      tier_id: tier_pricing.tier_id,
      tier_pricing_id: tier_pricing.id,
      amount: amount,
      phone_number: seller.phone_number,
      status: 'pending_verification',
      transaction_type: 'manual_verification',
      checkout_request_id: "VERIFY_#{transaction_id}",
      merchant_request_id: "VERIFY_#{transaction_id}",
      mpesa_receipt_number: transaction_id,
      transaction_date: Time.current.strftime("%Y%m%d%H%M%S"),
      callback_phone_number: seller.phone_number,
      callback_amount: amount
    )

    {
      success: true,
      message: "Payment verification initiated",
      payment_transaction: payment_transaction,
      tier_name: tier_pricing.tier.name,
      amount: amount
    }
  end

  def self.confirm_manual_payment(payment_transaction_id, mpesa_receipt_number)
    payment_transaction = PaymentTransaction.find_by(id: payment_transaction_id)
    return { success: false, error: "Payment transaction not found" } unless payment_transaction

    if payment_transaction.status != 'pending_verification'
      return { success: false, error: "Payment is not pending verification" }
    end

    ActiveRecord::Base.transaction do
      # Update payment transaction
      payment_transaction.update!(
        status: 'completed',
        mpesa_receipt_number: mpesa_receipt_number,
        completed_at: Time.current
      )

      # Create payment record
      Payment.create!(
        transaction_type: "CustomerPayBillOnline",
        trans_id: mpesa_receipt_number,
        trans_time: Time.current.strftime("%Y%m%d%H%M%S"),
        trans_amount: payment_transaction.amount.to_s,
        business_short_code: MpesaStkService::BUSINESS_SHORT_CODE,
        bill_ref_number: "TIER#{payment_transaction.tier_id}_#{payment_transaction.seller_id}",
        invoice_number: payment_transaction.id.to_s,
        org_account_balance: "0",
        third_party_trans_id: payment_transaction.checkout_request_id,
        msisdn: payment_transaction.phone_number,
        first_name: payment_transaction.seller.fullname.split.first,
        middle_name: "",
        last_name: payment_transaction.seller.fullname.split.last
      )

      # Activate seller tier
      activate_seller_tier(payment_transaction)

      {
        success: true,
        message: "Payment confirmed and tier activated",
        tier_name: payment_transaction.tier.name
      }
    end
  rescue => e
    Rails.logger.error("Error confirming manual payment: #{e.message}")
    { success: false, error: "Error confirming payment" }
  end

  def self.get_payment_instructions(seller_id, tier_id, amount)
    seller = Seller.find_by(id: seller_id)
    tier = Tier.find_by(id: tier_id)
    
    return { success: false, error: "Seller or tier not found" } unless seller && tier

    account_reference = "TIER#{tier_id}_#{seller_id}"
    
    {
      success: true,
      instructions: {
        paybill_number: MpesaStkService::BUSINESS_SHORT_CODE,
        account_number: account_reference,
        amount: amount,
        tier_name: tier.name,
        seller_name: seller.fullname
      }
    }
  end

  private

  def self.activate_seller_tier(payment_transaction)
    seller = payment_transaction.seller
    tier = payment_transaction.tier
    tier_pricing = payment_transaction.tier_pricing

    # Create or update seller tier
    seller_tier = SellerTier.find_or_initialize_by(seller_id: seller.id)
    
    # Calculate expiration date
    if tier.id == 1 # Free tier
      expiration_date = nil
    else
      expiration_date = Time.current + tier_pricing.duration_months.months
    end

    seller_tier.update!(
      tier_id: tier.id,
      duration_months: tier_pricing.duration_months,
      expires_at: expiration_date,
      payment_transaction_id: payment_transaction.id
    )

    # Send notification to seller
    Notification.create!(
      notifiable: seller,
      title: "Tier Upgrade Successful",
      message: "Your #{tier.name} tier has been activated successfully!",
      notification_type: "tier_upgrade"
    )

    Rails.logger.info("Tier activated for seller #{seller.id}: #{tier.name}")
  end
end
