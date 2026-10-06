class BackfillSellerWhatsappUrls < ActiveRecord::Migration[7.1]
  def up
    Seller.where(whatsapp_url: [nil, ""]).find_each do |seller|
      number = seller.secondary_phone_number.presence || seller.phone_number
      digits = wa_me_digits(number)
      seller.update_columns(whatsapp_url: "https://wa.me/#{digits}") if digits
    end
  end

  def down
    # Irreversible: can't tell backfilled URLs from ones sellers set themselves.
  end

  private

  # Normalize a Kenyan phone to wa.me digits (254XXXXXXXXX). Returns nil when
  # the input doesn't look like a usable mobile/landline number.
  def wa_me_digits(raw)
    digits = raw.to_s.gsub(/\D/, "")
    if digits.start_with?("00254")
      digits = "254#{digits[5..]}"
    elsif digits.start_with?("0")
      digits = "254#{digits[1..]}"
    elsif digits.match?(/\A[17]\d{8}\z/)
      digits = "254#{digits}"
    end
    digits.match?(/\A254\d{9}\z/) ? digits : nil
  end
end
