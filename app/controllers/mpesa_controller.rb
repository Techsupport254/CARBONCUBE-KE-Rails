class MpesaController < ApplicationController

  # Skip CSRF protection for specific actions
  skip_before_action :verify_authenticity_token, only: [:validate_payment, :confirm_payment]

  def validate_payment
    data = JSON.parse(request.body.read)
    account_number = data["BillRefNumber"]

    # Check if this is a manual paybill payment
    if account_number&.start_with?("TIER")
      parts = account_number.split("_")
      if parts.length >= 2
        tier_id = parts[0].gsub("TIER", "").to_i
        seller_id = parts[1]
        
        seller = Seller.find_by(id: seller_id)
        tier = Tier.find_by(id: tier_id)
        
        if seller && tier
          render json: { ResultCode: 0, ResultDesc: "Accepted" }
        else
          render json: { ResultCode: "C2B00012", ResultDesc: "Invalid Account Number" }
        end
      else
        render json: { ResultCode: "C2B00012", ResultDesc: "Invalid Account Number" }
      end
    else
      # Original logic for phone number based payments
      seller = Seller.find_by(phone_number: account_number) || Seller.find_by(business_registration_number: account_number)

      if seller
        render json: { ResultCode: 0, ResultDesc: "Accepted" }
      else
        render json: { ResultCode: "C2B00012", ResultDesc: "Invalid Account Number" }
      end
    end
  end

  def confirm_payment
    data = JSON.parse(request.body.read)
  
    account_number = data["BillRefNumber"]
    amount = data["TransAmount"].to_f
    transaction_id = data["TransID"]
    phone_number = data["MSISDN"]
  
    # Check if this is a manual paybill payment
    if account_number&.start_with?("TIER")
      process_manual_paybill_payment(data)
    else
      process_phone_number_payment(data)
    end

    render json: { ResultCode: 0, ResultDesc: "Success" }
  rescue => e
    Rails.logger.error("Payment confirmation error: #{e.message}")
    render json: { ResultCode: 1, ResultDesc: "Error processing payment" }
  end

  private

  def process_manual_paybill_payment(data)
    account_number = data["BillRefNumber"]
    amount = data["TransAmount"].to_f
    transaction_id = data["TransID"]
    phone_number = data["MSISDN"]

    parts = account_number.split("_")
    return unless parts.length >= 2

    tier_id = parts[0].gsub("TIER", "").to_i
    seller_id = parts[1]

    seller = Seller.find_by(id: seller_id)
    tier = Tier.find_by(id: tier_id)

    return unless seller && tier

    # Find matching tier pricing
    tier_pricing = TierPricing.find_by(tier_id: tier_id, price: amount)
    
    unless tier_pricing
      Rails.logger.error("No matching tier pricing found for tier #{tier_id} with amount #{amount}")
      return
    end

    # Check if payment already exists
    existing_payment = Payment.find_by(trans_id: transaction_id)
    if existing_payment
      Rails.logger.info("Payment #{transaction_id} already processed")
      return
    end

    ActiveRecord::Base.transaction do
      # Create payment record
      payment = Payment.create!(
        transaction_type: data["TransactionType"],
        trans_id: transaction_id,
        trans_time: data["TransTime"],
        trans_amount: amount.to_s,
        business_short_code: data["BusinessShortCode"],
        bill_ref_number: account_number,
        invoice_number: data["InvoiceNumber"],
        org_account_balance: data["OrgAccountBalance"],
        third_party_trans_id: data["ThirdPartyTransID"],
        msisdn: phone_number,
        first_name: data["FirstName"],
        middle_name: data["MiddleName"],
        last_name: data["LastName"]
      )

      # Create payment transaction record
      payment_transaction = PaymentTransaction.create!(
        seller_id: seller.id,
        tier_id: tier.id,
        tier_pricing_id: tier_pricing.id,
        amount: amount,
        phone_number: phone_number,
        status: 'completed',
        transaction_type: 'manual_paybill',
        checkout_request_id: "MANUAL_#{transaction_id}",
        merchant_request_id: "MANUAL_#{transaction_id}",
        mpesa_receipt_number: transaction_id,
        transaction_date: data["TransTime"],
        callback_phone_number: phone_number,
        callback_amount: amount,
        completed_at: Time.current
      )

      # Activate seller tier
      activate_seller_tier_from_payment(payment_transaction)

      Rails.logger.info("Manual paybill payment processed: #{transaction_id} for seller #{seller.id}")
    end
  end

  def process_phone_number_payment(data)
    account_number = data["BillRefNumber"]
    amount = data["TransAmount"].to_f
    transaction_id = data["TransID"]
    phone_number = data["MSISDN"]

    seller = Seller.find_by(phone_number: account_number)

    unless seller
      Rails.logger.error("Seller not found for phone number: #{account_number}")
      return
    end

    # Check if payment already exists
    existing_payment = Payment.find_by(trans_id: transaction_id)
    if existing_payment
      Rails.logger.info("Payment #{transaction_id} already processed")
      return
    end

    ActiveRecord::Base.transaction do
      # Create payment record
      payment = Payment.create!(
        transaction_type: data["TransactionType"],
        trans_id: transaction_id,
        trans_time: data["TransTime"],
        trans_amount: amount.to_s,
        business_short_code: data["BusinessShortCode"],
        bill_ref_number: account_number,
        invoice_number: data["InvoiceNumber"],
        org_account_balance: data["OrgAccountBalance"],
        third_party_trans_id: data["ThirdPartyTransID"],
        msisdn: phone_number,
        first_name: data["FirstName"],
        middle_name: data["MiddleName"],
        last_name: data["LastName"]
      )

      # Find matching tier pricing
      tier_pricing = TierPricing.find_by(price: amount)

      if tier_pricing
        # Create payment transaction record
        payment_transaction = PaymentTransaction.create!(
          seller_id: seller.id,
          tier_id: tier_pricing.tier_id,
          tier_pricing_id: tier_pricing.id,
          amount: amount,
          phone_number: phone_number,
          status: 'completed',
          transaction_type: 'manual_paybill',
          checkout_request_id: "MANUAL_#{transaction_id}",
          merchant_request_id: "MANUAL_#{transaction_id}",
          mpesa_receipt_number: transaction_id,
          transaction_date: data["TransTime"],
          callback_phone_number: phone_number,
          callback_amount: amount,
          completed_at: Time.current
        )

        # Activate seller tier
        activate_seller_tier_from_payment(payment_transaction)

        Rails.logger.info("Phone number payment processed: #{transaction_id} for seller #{seller.id}")
      else
        Rails.logger.error("No matching tier pricing found for amount #{amount}")
      end
    end
  end

  def activate_seller_tier_from_payment(payment_transaction)
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
