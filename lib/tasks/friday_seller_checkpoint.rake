namespace :admin do
  desc "Export new sellers since last checkpoint and send via email"
  task friday_seller_checkpoint: :environment do
    require 'csv'

    # Find sellers that haven't been exported yet
    unexported_sellers = Seller.where(checkpoint_exported: false)
    seller_count = unexported_sellers.count

    if seller_count == 0
      puts "No new sellers to export."
      # We still send an email so the admin knows the job ran successfully
    end

    require 'prawn'
    require 'prawn/table'

    csv_data = CSV.generate(headers: true) do |csv|
      csv << ["Date Registered", "Company Name", "Location", "Name of Contact", "Contact Number", "Category"]
      unexported_sellers.includes(:category).each do |seller|
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

    # Generate PDF
    pdf = Prawn::Document.new(page_layout: :landscape)
    pdf.text "Weekly Seller Checkpoint - #{Date.today.to_s}", size: 18, style: :bold
    pdf.move_down 20
    
    table_data = [["Date", "Company Name", "Location", "Contact Name", "Number", "Category"]]
    unexported_sellers.includes(:category).each do |seller|
      table_data << [
        seller.created_at&.strftime("%Y-%m-%d").to_s,
        seller.enterprise_name.to_s,
        seller.location.to_s,
        seller.fullname.to_s,
        seller.phone_number.to_s,
        seller.category&.name || "N/A"
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
      "beverlyne.sales@carboncube-ke.com"
    ]

    # Send email
    AdminReportsMailer.weekly_seller_checkpoint(admin_emails, csv_data, pdf_content, seller_count).deliver_now

    # Mark as exported
    unexported_sellers.update_all(checkpoint_exported: true)

    puts "Successfully exported and emailed #{seller_count} sellers."
  end
end
