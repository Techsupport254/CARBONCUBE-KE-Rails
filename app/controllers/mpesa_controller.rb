class MpesaController < ApplicationController

  # Skip CSRF protection for specific actions
  skip_before_action :verify_authenticity_token, only: [:validate_payment, :confirm_payment]

  def validate_payment
    data = JSON.parse(request.body.read)
    account_number = data["BillRefNumber"]

    seller = Seller.find_by(phone_number: account_number) || Seller.find_by(business_registration_number: account_number)

    if seller
      render json: { ResultCode: 0, ResultDesc: "Accepted" }
    else
      render json: { ResultCode: "C2B00012", ResultDesc: "Invalid Account Number" }
    end
  end

  def confirm_payment
    data = JSON.parse(request.body.read)
  
    account_number = data["BillRefNumber"]
    amount = data["TransAmount"].to_f
  
    seller = Seller.find_by(phone_number: account_number) # || Seller.find_by(business_registration_number: account_number)
  
    Payment.create!(
      transaction_type: data["TransactionType"],
      trans_id: data["TransID"],
      trans_time: data["TransTime"],
      trans_amount: data["TransAmount"],
      business_short_code: data["BusinessShortCode"],
      bill_ref_number: data["BillRefNumber"],
      invoice_number: data["InvoiceNumber"],
      org_account_balance: data["OrgAccountBalance"],
      third_party_trans_id: data["ThirdPartyTransID"],
      msisdn: data["MSISDN"],
      first_name: data["FirstName"],
      middle_name: data["MiddleName"],
      last_name: data["LastName"]
    )
  
    if seller
      tier_pricing = TierPricing.find_by(price: amount)
  
      if tier_pricing
        seller_tier = SellerTier.find_or_initialize_by(seller_id: seller.id)
  
        seller_tier.update!(
          tier_id: tier_pricing.tier_id,
          duration_months: tier_pricing.duration_months
        )
  
        render json: { ResultCode: 0, ResultDesc: "Success" }
      else
        render json: { ResultCode: "C2B00013", ResultDesc: "Invalid Amount - No Matching Tier Pricing" }
      end
    else
      render json: { ResultCode: "C2B00012", ResultDesc: "Invalid Account Number" }
    end
  end
end
