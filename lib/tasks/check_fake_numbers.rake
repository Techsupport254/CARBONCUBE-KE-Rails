namespace :admin do
  desc "Check sellers for fake/invalid Kenyan phone numbers and export results to CSV"
  task check_fake_numbers: :environment do
    require 'csv'

    # Valid Kenyan mobile prefixes (first 3-4 digits after leading 0)
    # Source: Communications Authority of Kenya (CA) Numbering Plan, November 2025
    VALID_PREFIXES = {
      'Safaricom' => %w[
        070 071 072
        0740 0741 0742 0743 0745 0746 0748
        0757 0758 0759
        0768 0769
        079
        0110 0111 0112 0113 0114 0115
      ],
      'Airtel' => %w[
        0730 0731 0732 0733 0734 0735 0736 0737 0738 0739
        0750 0751 0752 0753 0754 0755 0756
        0780 0781 0782 0783 0784 0785 0786 0787 0788 0789
        0100 0101 0102 0103 0104 0105 0106 0107 0108
      ],
      'Telkom Kenya' => %w[
        0770 0771 0772 0773 0774 0775 0776 0777 0778 0779
      ],
      'Equitel' => %w[
        0763 0764 0765 0766
      ],
      'Faiba' => %w[
        0747
      ]
    }.freeze

    # Build a lookup hash: prefix => operator name
    PREFIX_TO_OPERATOR = VALID_PREFIXES.each_with_object({}) do |(operator, prefixes), hash|
      prefixes.each { |p| hash[p] = operator }
    end.freeze

    def identify_operator(number)
      return nil if number.blank?
      digits = number.to_s.gsub(/\D/, '')
      # Normalize: strip leading 254, ensure leading 0
      if digits.start_with?('254')
        digits = '0' + digits[3..]
      elsif digits.length == 9 && digits.match?(/^[17]/)
        digits = '0' + digits
      end
      # Try 4-digit prefix first (for 01XX and specific 07XX ranges), then 3-digit
      PREFIX_TO_OPERATOR[digits[0..3]] || PREFIX_TO_OPERATOR[digits[0..2]]
    end

    def valid_kenyan_mobile?(number)
      return false if number.blank?
      digits = number.to_s.gsub(/\D/, '')
      if digits.start_with?('254')
        digits = '0' + digits[3..]
      elsif digits.length == 9 && digits.match?(/^[17]/)
        digits = '0' + digits
      end
      # Must be 10 digits starting with 07 or 01
      return false unless digits.match?(/^0[17]\d{8}$/)
      !identify_operator(digits).nil?
    end

    puts "Scanning all sellers for fake/invalid Kenyan phone numbers..."
    puts "=" * 80

    sellers = Seller.all
    total = sellers.count
    puts "Total sellers in database: #{total}"
    puts ""

    fake_records = []
    checked = 0

    sellers.find_each(batch_size: 500) do |seller|
      checked += 1
      primary = seller.phone_number
      secondary = seller.secondary_phone_number

      primary_fake = primary.present? && !valid_kenyan_mobile?(primary)
      secondary_fake = secondary.present? && !valid_kenyan_mobile?(secondary)

      next unless primary_fake || secondary_fake

      fake_records << {
        id: seller.id,
        fullname: seller.fullname,
        enterprise_name: seller.enterprise_name,
        email: seller.email,
        phone_number: primary,
        phone_operator: identify_operator(primary),
        phone_valid: valid_kenyan_mobile?(primary),
        secondary_phone_number: secondary,
        secondary_operator: identify_operator(secondary),
        secondary_valid: valid_kenyan_mobile?(secondary),
        created_at: seller.created_at,
        blocked: seller.blocked?,
        deleted: seller.deleted?
      }
    end

    puts "Checked #{checked} sellers"
    puts "Found #{fake_records.size} seller(s) with invalid phone numbers"
    puts "=" * 80

    if fake_records.empty?
      puts "All phone numbers are valid Kenyan mobile numbers."
      next
    end

    # Print summary table
    puts ""
    puts "%-40s %-15s %-12s %-15s %-12s" % ["Seller", "Phone", "Valid?", "Secondary", "Valid?"]
    puts "-" * 100
    fake_records.each do |r|
      puts "%-40s %-15s %-12s %-15s %-12s" % [
        "#{r[:fullname]} (#{r[:enterprise_name]})",
        r[:phone_number] || 'N/A',
        r[:phone_valid] ? 'YES' : 'NO',
        r[:secondary_phone_number] || 'N/A',
        r[:secondary_valid] ? 'YES' : 'NO'
      ]
    end

    # Export to CSV
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    csv_path = Rails.root.join('tmp', "fake_numbers_report_#{timestamp}.csv")
    FileUtils.mkdir_p(File.dirname(csv_path))

    CSV.open(csv_path, 'wb') do |csv|
      csv << ['Seller ID', 'Fullname', 'Enterprise', 'Email', 'Phone Number', 'Phone Operator', 'Phone Valid',
              'Secondary Phone', 'Secondary Operator', 'Secondary Valid', 'Created At', 'Blocked', 'Deleted']
      fake_records.each do |r|
        csv << [r[:id], r[:fullname], r[:enterprise_name], r[:email],
                r[:phone_number], r[:phone_operator] || 'INVALID', r[:phone_valid],
                r[:secondary_phone_number], r[:secondary_operator] || 'N/A', r[:secondary_valid],
                r[:created_at]&.strftime('%Y-%m-%d'), r[:blocked], r[:deleted]]
      end
    end

    puts ""
    puts "CSV report saved to: #{csv_path}"
    puts ""
    puts "Summary:"
    puts "  - Total sellers checked:     #{checked}"
    puts "  - Sellers with fake numbers: #{fake_records.size}"
    puts "  - Fake primary numbers:      #{fake_records.count { |r| !r[:phone_valid] }}"
    puts "  - Fake secondary numbers:    #{fake_records.count { |r| r[:secondary_phone_number].present? && !r[:secondary_valid] }}"
  end
end
