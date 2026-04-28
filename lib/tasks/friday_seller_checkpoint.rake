namespace :admin do
  desc "Export new sellers from last Friday to this Friday and send via email"
  task friday_seller_checkpoint: :environment do
    require 'csv'

    # Calculate date range from last Friday to this Friday
    today = Date.today
    this_friday = today + ((5 - today.wday) % 7)
    last_friday = this_friday - 7

    puts "Exporting sellers from #{last_friday} to #{this_friday}"

    # Find sellers in the date range
    sellers = Seller.where('created_at >= ? AND created_at <= ?', last_friday, this_friday.end_of_day)
    seller_count = sellers.count

    if seller_count == 0
      puts "No sellers found in the specified date range."
      # We still send an email so the admin knows the job ran successfully
    else
      puts "Found #{seller_count} sellers to export"
    end

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

    # Generate PDF with UTF-8 support
    require 'prawn'
    require 'prawn/table'

    pdf = Prawn::Document.new(page_layout: :landscape)
    pdf.font "Helvetica"
    pdf.text "Weekly Seller Checkpoint: #{last_friday} to #{this_friday}", size: 18, style: :bold
    pdf.move_down 20

    # Sanitize text for PDF
    sanitize = lambda { |text|
      text.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
    }

    table_data = [["Date", "Company Name", "Location", "Contact Name", "Number", "Category"]]
    sellers.includes(:category).each do |seller|
      table_data << [
        sanitize.call(seller.created_at&.strftime("%Y-%m-%d")),
        sanitize.call(seller.enterprise_name),
        sanitize.call(seller.location),
        sanitize.call(seller.fullname),
        sanitize.call(seller.phone_number),
        sanitize.call(seller.category&.name || "N/A")
      ]
    end

    pdf.table(table_data, header: true, width: pdf.bounds.width) do
      row(0).font_style = :bold
      row(0).background_color = 'DDDDDD'
      cells.padding = [5, 5]
      cells.size = 10
    end
    pdf_content = pdf.render

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
