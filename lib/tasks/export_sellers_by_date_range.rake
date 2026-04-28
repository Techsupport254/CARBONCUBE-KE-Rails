namespace :admin do
  desc "Export sellers by date range (START_DATE and END_DATE required)"
  task export_sellers_by_date: :environment do
    require 'csv'
    require 'prawn'
    require 'prawn/table'

    # Get date parameters
    start_date = ENV['START_DATE'] || '2025-04-14'
    end_date = ENV['END_DATE'] || Date.today.to_s

    puts "Exporting sellers from #{start_date} to #{end_date}"

    # Find sellers in the date range
    sellers = Seller.where('created_at >= ? AND created_at <= ?', start_date, end_date)
    seller_count = sellers.count

    if seller_count == 0
      puts "No sellers found in the specified date range."
      next
    end

    puts "Found #{seller_count} sellers to export"

    # Generate CSV
    csv_data = CSV.generate(headers: true) do |csv|
      csv << ["Date Registered", "Company Name", "Location", "Name of Contact", "Contact Number", "Category"]
      sellers.includes(:category).each do |seller|
        csv << [
          seller.created_at&.strftime("%Y-%m-%d"),
          seller.enterprise_name,
          seller.location,
          seller.fullname,
          seller.phone_number,
          seller.category&.name || "N/A"
        ]
      end
    end

    # Skip PDF due to encoding issues - CSV is sufficient for this export
    pdf_content = nil

    # Define admin emails
    admin_emails = [
      "victor@carboncube-ke.com",
      "beverlyne.sales@carboncube-ke.com",
      "arwabeverlyne2@gmail.com",
      "kiruivictor097@gmail.com"
    ]

    # Send email to each admin
    admin_emails.each do |email|
      AdminReportsMailer.weekly_seller_checkpoint(email, csv_data, pdf_content, seller_count).deliver_now
      puts "Sent email to #{email}"
    end

    puts "Successfully exported and emailed #{seller_count} sellers."
  end
end
