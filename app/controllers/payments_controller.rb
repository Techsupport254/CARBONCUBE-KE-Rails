class PaymentsController < ApplicationController
  before_action :authenticate_seller, only: [:initiate_payment, :check_payment_status, :manual_payment_instructions, :verify_manual_payment, :confirm_manual_payment, :payment_history, :cancel_payment]
  skip_before_action :verify_authenticity_token, only: [:stk_callback]

  # Initiate STK Push payment for tier upgrade
  def initiate_payment
    begin
      # Validate required parameters
      tier_id = params[:tier_id]
      pricing_id = params[:pricing_id]
      phone_number = params[:phone_number]

      if tier_id.blank? || pricing_id.blank? || phone_number.blank?
        return render json: { 
          success: false, 
          error: "Missing required parameters: tier_id, pricing_id, phone_number" 
        }, status: :bad_request
      end

      # Find tier and pricing
      tier = Tier.find(tier_id)
      pricing = TierPricing.find(pricing_id)
      
      # Validate pricing belongs to tier
      unless pricing.tier_id == tier.id
        return render json: { 
          success: false, 
          error: "Pricing does not belong to selected tier" 
        }, status: :unprocessable_entity
      end

      # Validate phone number format (basic validation)
      cleaned_phone = phone_number.to_s.gsub(/\D/, '')
      unless cleaned_phone.length >= 7 && cleaned_phone.length <= 15
        return render json: {
          success: false,
          error: "Invalid phone number format"
        }, status: :unprocessable_entity
      end

      # Get current seller's subscription status
      current_seller_tier = current_seller.seller_tier
      current_tier = current_seller_tier&.tier

      # Edge Case 1: Check for active subscription and prevent downgrades
      if current_seller_tier && !current_seller_tier.expired?
        if tier.id <= current_tier.id
          return render json: { 
            success: false, 
            error: "You already have an active #{current_tier.name} subscription. You can only upgrade to a higher tier." 
          }, status: :unprocessable_entity
        end
        
        # Check if it's a valid upgrade (higher tier)
        unless tier.id > current_tier.id
          return render json: { 
            success: false, 
            error: "Invalid upgrade. You can only upgrade to a higher tier than your current #{current_tier.name} subscription." 
          }, status: :unprocessable_entity
        end
      end

      # Edge Case 2: Prevent double payments for the same tier
      existing_payment = PaymentTransaction.find_by(
        seller_id: current_seller.id,
        tier_id: tier.id,
        status: ['initiated', 'pending', 'processing']
      )

      if existing_payment
        return render json: { 
          success: false, 
          error: "You already have a pending payment for #{tier.name} tier. Please wait for it to complete or cancel it first." 
        }, status: :unprocessable_entity
      end

      # Edge Case 3: Check for recent failed payments to prevent spam
      recent_failed_payment = PaymentTransaction.where(
        seller_id: current_seller.id,
        tier_id: tier.id,
        status: 'failed'
      ).where('created_at > ?', 5.minutes.ago).first

      if recent_failed_payment
        return render json: { 
          success: false, 
          error: "Please wait 5 minutes before retrying payment for #{tier.name} tier." 
        }, status: :unprocessable_entity
      end

      # Edge Case 4: Validate amount is reasonable
      if pricing.price > 1000000 # 1M KES limit
        return render json: { 
          success: false, 
          error: "Payment amount exceeds maximum limit" 
        }, status: :unprocessable_entity
      end

      # Edge Case 5: Check for expired pending payments and clean them up
      PaymentTransaction.where(
        seller_id: current_seller.id,
        status: ['initiated', 'pending']
      ).where('created_at < ?', 10.minutes.ago).update_all(status: 'cancelled')

      # Create payment transaction record
      payment_transaction = PaymentTransaction.create!(
        seller_id: current_seller.id,
        tier_id: tier.id,
        tier_pricing_id: pricing.id,
        amount: pricing.price,
        phone_number: phone_number,
        status: 'initiated',
        transaction_type: 'tier_upgrade',
        checkout_request_id: SecureRandom.uuid,
        merchant_request_id: SecureRandom.uuid
      )

      # Initiate STK Push
      stk_result = MpesaStkService.initiate_stk_push(
        phone_number,
        pricing.price,
        "TIER#{tier.id}_#{current_seller.id}",
        "Carbon Cube Tier Upgrade - #{tier.name}"
      )

      if stk_result[:success]
        # Update payment transaction with STK details
        payment_transaction.update!(
          checkout_request_id: stk_result[:checkout_request_id],
          merchant_request_id: stk_result[:merchant_request_id],
          status: 'pending',
          stk_response_code: stk_result[:response_code],
          stk_response_description: stk_result[:response_description]
        )

        render json: {
          success: true,
          message: stk_result[:customer_message],
          payment_id: payment_transaction.id,
          checkout_request_id: stk_result[:checkout_request_id],
          merchant_request_id: stk_result[:merchant_request_id]
        }
      else
        payment_transaction.update!(status: 'failed', error_message: stk_result[:error])
        render json: { 
          success: false, 
          error: stk_result[:error] 
        }, status: :unprocessable_entity
      end

    rescue ActiveRecord::RecordNotFound => e
      render json: { 
        success: false, 
        error: "Tier or pricing not found" 
      }, status: :not_found
    rescue => e
      Rails.logger.error("Payment initiation error: #{e.message}")
      render json: { 
        success: false, 
        error: "An error occurred while processing your payment" 
      }, status: :internal_server_error
    end
  end

  # Check payment status
  def check_payment_status
    payment_id = params[:payment_id]
    
    unless payment_id
      return render json: { 
        success: false, 
        error: "Payment ID is required" 
      }, status: :bad_request
    end

    payment_transaction = PaymentTransaction.find_by(
      id: payment_id,
      seller_id: current_seller.id
    )

    unless payment_transaction
      return render json: { 
        success: false, 
        error: "Payment not found" 
      }, status: :not_found
    end

    # If payment is still pending, query M-Pesa for status
    if payment_transaction.status == 'pending' && payment_transaction.checkout_request_id.present?
      query_result = MpesaStkService.query_stk_push_status(payment_transaction.checkout_request_id)
      
      if query_result[:success]
        case query_result[:result_code]
        when "0"
          payment_transaction.update!(status: 'completed')
        when "1"
          payment_transaction.update!(status: 'processing')
        else
          payment_transaction.update!(status: 'failed', error_message: query_result[:result_desc])
        end
      end
    end

    render json: {
      success: true,
      payment: {
        id: payment_transaction.id,
        status: payment_transaction.status,
        amount: payment_transaction.amount,
        tier_name: payment_transaction.tier.name,
        created_at: payment_transaction.created_at,
        updated_at: payment_transaction.updated_at,
        error_message: payment_transaction.error_message
      }
    }
  end

  # M-Pesa STK Push callback
  def stk_callback
    begin
      callback_data = JSON.parse(request.body.read)
      Rails.logger.info("STK Callback received: #{callback_data}")

      # Extract callback data
      body = callback_data["Body"]
      stk_callback_data = body["stkCallback"]
      
      checkout_request_id = stk_callback_data["CheckoutRequestID"]
      result_code = stk_callback_data["ResultCode"]
      result_desc = stk_callback_data["ResultDesc"]

      # Find payment transaction
      payment_transaction = PaymentTransaction.find_by(checkout_request_id: checkout_request_id)
      
      unless payment_transaction
        Rails.logger.error("Payment transaction not found for checkout_request_id: #{checkout_request_id}")
        return render json: { ResultCode: 0, ResultDesc: "Success" }
      end

      # Process callback based on result code
      case result_code
      when 0
        # Payment successful
        callback_metadata = stk_callback_data["CallbackMetadata"]
        if callback_metadata && callback_metadata["Item"]
          items = callback_metadata["Item"]
          
          # Extract payment details
          mpesa_receipt_number = items.find { |item| item["Name"] == "MpesaReceiptNumber" }&.dig("Value")
          transaction_date = items.find { |item| item["Name"] == "TransactionDate" }&.dig("Value")
          phone_number = items.find { |item| item["Name"] == "PhoneNumber" }&.dig("Value")
          amount = items.find { |item| item["Name"] == "Amount" }&.dig("Value")

          # Update payment transaction
          payment_transaction.update!(
            status: 'completed',
            mpesa_receipt_number: mpesa_receipt_number,
            transaction_date: transaction_date,
            callback_phone_number: phone_number,
            callback_amount: amount,
            completed_at: Time.current
          )

          # Activate seller tier
          activate_seller_tier(payment_transaction)
        end
      else
        # Payment failed
        payment_transaction.update!(
          status: 'failed',
          error_message: result_desc,
          failed_at: Time.current
        )
      end

      render json: { ResultCode: 0, ResultDesc: "Success" }
    rescue => e
      Rails.logger.error("STK Callback error: #{e.message}")
      render json: { ResultCode: 1, ResultDesc: "Error processing callback" }
    end
  end

  # Get seller's payment history
  def payment_history
    payments = PaymentTransaction.where(seller_id: current_seller.id)
                                .includes(:tier, :tier_pricing)
                                .order(created_at: :desc)
                                .limit(20)

    render json: {
      success: true,
      payments: payments.map do |payment|
        {
          id: payment.id,
          tier_name: payment.tier.name,
          amount: payment.amount,
          status: payment.status,
          created_at: payment.created_at,
          completed_at: payment.completed_at,
          mpesa_receipt_number: payment.mpesa_receipt_number
        }
      end
    }
  end

  # Get manual payment instructions
  def manual_payment_instructions
    tier_id = params[:tier_id]
    pricing_id = params[:pricing_id]

    unless tier_id && pricing_id
      return render json: { 
        success: false, 
        error: "Tier ID and pricing ID are required" 
      }, status: :bad_request
    end

    tier = Tier.find(tier_id)
    pricing = TierPricing.find(pricing_id)

    # Validate pricing belongs to tier
    unless pricing.tier_id == tier.id
      return render json: { 
        success: false, 
        error: "Pricing does not belong to selected tier" 
      }, status: :unprocessable_entity
    end

    # Get current seller's subscription status
    current_seller_tier = current_seller.seller_tier
    current_tier = current_seller_tier&.tier

    # Edge Case: Check for active subscription and prevent downgrades
    if current_seller_tier && !current_seller_tier.expired?
      if tier.id <= current_tier.id
        return render json: { 
          success: false, 
          error: "You already have an active #{current_tier.name} subscription. You can only upgrade to a higher tier." 
        }, status: :unprocessable_entity
      end
    end

    # Edge Case: Check for existing manual payment instructions
    existing_manual_payment = PaymentTransaction.where(
      seller_id: current_seller.id,
      tier_id: tier.id,
      status: ['initiated', 'pending']
    ).where('created_at > ?', 1.hour.ago).first

    if existing_manual_payment
      return render json: { 
        success: false, 
        error: "You already have pending payment instructions for #{tier.name} tier. Please wait for it to complete or try again later." 
      }, status: :unprocessable_entity
    end

    result = PaymentVerificationService.get_payment_instructions(
      current_seller.id, 
      tier_id, 
      pricing.price
    )

    if result[:success]
      render json: {
        success: true,
        instructions: result[:instructions],
        tier_name: tier.name,
        duration_months: pricing.duration_months
      }
    else
      render json: { 
        success: false, 
        error: result[:error] 
      }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { 
      success: false, 
      error: "Tier or pricing not found" 
    }, status: :not_found
  end

  # Verify manual payment
  def verify_manual_payment
    transaction_id = params[:transaction_id]
    amount = params[:amount]

    unless transaction_id && amount
      return render json: { 
        success: false, 
        error: "Transaction ID and amount are required" 
      }, status: :bad_request
    end

    # Edge Case: Validate amount format and range
    begin
      amount_float = amount.to_f
      if amount_float <= 0
        return render json: { 
          success: false, 
          error: "Amount must be greater than 0" 
        }, status: :bad_request
      end
      
      if amount_float > 1000000 # 1M KES limit
        return render json: { 
          success: false, 
          error: "Amount exceeds maximum limit" 
        }, status: :bad_request
      end
    rescue
      return render json: { 
        success: false, 
        error: "Invalid amount format" 
      }, status: :bad_request
    end

    # Edge Case: Check for duplicate transaction verification
    existing_verification = PaymentTransaction.where(
      seller_id: current_seller.id,
      mpesa_receipt_number: transaction_id,
      status: 'completed'
    ).first

    if existing_verification
      return render json: { 
        success: false, 
        error: "This transaction has already been verified and processed" 
      }, status: :unprocessable_entity
    end

    # Edge Case: Rate limiting for verification attempts
    recent_verification_attempts = PaymentTransaction.where(
      seller_id: current_seller.id,
      status: 'failed'
    ).where('created_at > ?', 1.hour.ago).count

    if recent_verification_attempts >= 5
      return render json: { 
        success: false, 
        error: "Too many failed verification attempts. Please wait 1 hour before trying again." 
      }, status: :too_many_requests
    end

    result = PaymentVerificationService.verify_manual_payment(
      current_seller.id,
      transaction_id,
      amount_float
    )

    if result[:success]
      render json: {
        success: true,
        message: result[:message],
        payment_transaction_id: result[:payment_transaction]&.id,
        tier_name: result[:tier_name],
        amount: result[:amount]
      }
    else
      render json: { 
        success: false, 
        error: result[:error] 
      }, status: :unprocessable_entity
    end
  end

  # Confirm manual payment
  def confirm_manual_payment
    payment_transaction_id = params[:payment_transaction_id]
    mpesa_receipt_number = params[:mpesa_receipt_number]

    unless payment_transaction_id && mpesa_receipt_number
      return render json: { 
        success: false, 
        error: "Payment transaction ID and M-Pesa receipt number are required" 
      }, status: :bad_request
    end

    # Edge Case: Validate payment transaction exists and belongs to seller
    payment_transaction = PaymentTransaction.find_by(
      id: payment_transaction_id,
      seller_id: current_seller.id
    )

    unless payment_transaction
      return render json: { 
        success: false, 
        error: "Payment transaction not found or does not belong to you" 
      }, status: :not_found
    end

    # Edge Case: Check if payment is already confirmed
    if payment_transaction.status == 'completed'
      return render json: { 
        success: false, 
        error: "This payment has already been confirmed" 
      }, status: :unprocessable_entity
    end

    # Edge Case: Check if payment is in a valid state for confirmation
    unless ['pending', 'processing'].include?(payment_transaction.status)
      return render json: { 
        success: false, 
        error: "Payment is not in a valid state for confirmation" 
      }, status: :unprocessable_entity
    end

    # Edge Case: Validate receipt number format
    unless mpesa_receipt_number.match?(/^[A-Z0-9]{6,20}$/)
      return render json: { 
        success: false, 
        error: "Invalid M-Pesa receipt number format" 
      }, status: :bad_request
    end

    # Edge Case: Check for duplicate receipt numbers
    existing_receipt = PaymentTransaction.where(
      mpesa_receipt_number: mpesa_receipt_number,
      status: 'completed'
    ).where.not(id: payment_transaction_id).first

    if existing_receipt
      return render json: { 
        success: false, 
        error: "This M-Pesa receipt number has already been used" 
      }, status: :unprocessable_entity
    end

    result = PaymentVerificationService.confirm_manual_payment(
      payment_transaction_id,
      mpesa_receipt_number
    )

    if result[:success]
      # Refresh seller tier data
      fetchCurrentSellerTier if respond_to?(:fetchCurrentSellerTier)
      
      render json: {
        success: true,
        message: result[:message],
        tier_name: result[:tier_name]
      }
    else
      render json: { 
        success: false, 
        error: result[:error] 
      }, status: :unprocessable_entity
    end
  end

  # Cancel a pending payment
  def cancel_payment
    payment_id = params[:payment_id]
    
    unless payment_id
      return render json: { 
        success: false, 
        error: "Payment ID is required" 
      }, status: :bad_request
    end

    payment_transaction = PaymentTransaction.find_by(
      id: payment_id,
      seller_id: current_seller.id
    )

    unless payment_transaction
      return render json: { 
        success: false, 
        error: "Payment not found" 
      }, status: :not_found
    end

    # Edge Case: Only allow cancellation of pending payments
    unless ['initiated', 'pending', 'processing'].include?(payment_transaction.status)
      return render json: { 
        success: false, 
        error: "Only pending payments can be cancelled" 
      }, status: :unprocessable_entity
    end

    # Edge Case: Check if payment is too old to cancel (more than 10 minutes)
    if payment_transaction.created_at < 10.minutes.ago
      return render json: { 
        success: false, 
        error: "Payment is too old to cancel. Please contact support." 
      }, status: :unprocessable_entity
    end

    # Cancel the payment
    payment_transaction.update!(
      status: 'cancelled',
      cancelled_at: Time.current
    )

    render json: {
      success: true,
      message: "Payment cancelled successfully"
    }
  rescue => e
    Rails.logger.error("Payment cancellation error: #{e.message}")
    render json: { 
      success: false, 
      error: "An error occurred while cancelling the payment" 
    }, status: :internal_server_error
  end

  private

  def authenticate_seller
    @current_seller = SellerAuthorizeApiRequest.new(request.headers).result

    if @current_seller.nil?
      render json: { error: 'Not Authorized' }, status: :unauthorized
    elsif @current_seller.deleted?
      render json: { error: 'Account has been deleted' }, status: :unauthorized
    end
  end

  def current_seller
    @current_seller
  end

  def activate_seller_tier(payment_transaction)
    ActiveRecord::Base.transaction do
      seller = payment_transaction.seller
      tier = payment_transaction.tier
      tier_pricing = payment_transaction.tier_pricing

      # Edge Case: Check if seller tier is already active for this tier
      existing_seller_tier = SellerTier.find_by(seller_id: seller.id)
      if existing_seller_tier && existing_seller_tier.tier_id == tier.id && !existing_seller_tier.expired?
        Rails.logger.warn("Seller #{seller.id} already has active #{tier.name} subscription")
        return
      end

      # Edge Case: Validate payment transaction is completed
      unless payment_transaction.status == 'completed'
        Rails.logger.error("Cannot activate tier for incomplete payment: #{payment_transaction.id}")
        raise "Payment transaction must be completed before activating tier"
      end

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

      # Edge Case: Prevent duplicate payment records
      existing_payment = Payment.find_by(
        trans_id: payment_transaction.mpesa_receipt_number,
        business_short_code: MpesaStkService::BUSINESS_SHORT_CODE
      )

      unless existing_payment
        # Create payment record for M-Pesa integration
        Payment.create!(
          transaction_type: "CustomerPayBillOnline",
          trans_id: payment_transaction.mpesa_receipt_number,
          trans_time: payment_transaction.transaction_date,
          trans_amount: payment_transaction.amount.to_s,
          business_short_code: MpesaStkService::BUSINESS_SHORT_CODE,
          bill_ref_number: seller.phone_number,
          invoice_number: payment_transaction.id.to_s,
          org_account_balance: "0",
          third_party_trans_id: payment_transaction.checkout_request_id,
          msisdn: payment_transaction.callback_phone_number,
          first_name: seller.fullname.split.first,
          middle_name: "",
          last_name: seller.fullname.split.last
        )
      end

      # Edge Case: Prevent duplicate notifications
      recent_notification = Notification.where(
        notifiable: seller,
        notification_type: "tier_upgrade"
      ).where('created_at > ?', 1.hour.ago).first

      unless recent_notification
        # Send notification to seller
        Notification.create!(
          notifiable: seller,
          title: "Tier Upgrade Successful",
          message: "Your #{tier.name} tier has been activated successfully!",
          notification_type: "tier_upgrade"
        )
      end

      Rails.logger.info("Tier activated for seller #{seller.id}: #{tier.name}")
    end
  rescue => e
    Rails.logger.error("Error activating seller tier: #{e.message}")
    # Don't raise error to avoid breaking the callback
  end
end
