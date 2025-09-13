class CleanupDuplicateSellers < ActiveRecord::Migration[7.1]
  def up
    # Clean up duplicate enterprise names by adding unique suffixes
    puts "Cleaning up duplicate enterprise names..."
    
    # Handle 'sasatech africa' duplicates
    sellers_with_sasatech = Seller.where('LOWER(enterprise_name) = ?', 'sasatech africa')
    if sellers_with_sasatech.count > 1
      sellers_with_sasatech.order(:id).each_with_index do |seller, index|
        next if index == 0 # Keep the first one unchanged
        seller.update!(enterprise_name: "#{seller.enterprise_name} (#{seller.id})")
        puts "Updated seller #{seller.id} enterprise_name to: #{seller.enterprise_name}"
      end
    end
    
    # Handle 'hatua' duplicates
    sellers_with_hatua = Seller.where('LOWER(enterprise_name) = ?', 'hatua')
    if sellers_with_hatua.count > 1
      sellers_with_hatua.order(:id).each_with_index do |seller, index|
        next if index == 0 # Keep the first one unchanged
        seller.update!(enterprise_name: "#{seller.enterprise_name} (#{seller.id})")
        puts "Updated seller #{seller.id} enterprise_name to: #{seller.enterprise_name}"
      end
    end
    
    # Clean up duplicate phone numbers by adding unique suffixes
    puts "Cleaning up duplicate phone numbers..."
    
    # Handle phone number duplicates
    phone_duplicates = Seller.group(:phone_number).having('COUNT(*) > 1').count
    phone_duplicates.each do |phone, count|
      sellers_with_phone = Seller.where(phone_number: phone).order(:id)
      sellers_with_phone.each_with_index do |seller, index|
        next if index == 0 # Keep the first one unchanged
        # Generate a unique phone number by modifying the last digit
        new_phone = phone.dup
        new_phone[-1] = ((new_phone[-1].to_i + index) % 10).to_s
        seller.update!(phone_number: new_phone)
        puts "Updated seller #{seller.id} phone_number to: #{seller.phone_number}"
      end
    end
    
    puts "Duplicate cleanup completed!"
  end

  def down
    # This migration is not easily reversible
    # If needed, you would need to manually restore the original values
    puts "This migration cannot be automatically reversed."
  end
end
