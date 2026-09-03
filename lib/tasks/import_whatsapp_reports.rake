# frozen_string_literal: true

require "date"

# One-off import of the daily reports that were previously shared in the
# Carbon Cube Seller Campaign WhatsApp group.  Run with:
#
#   bundle exec rake import:whatsapp_reports
#
# The task looks up sales users by their carbon codes (DUKE, ANNA, ADE).
namespace :import do
  desc "Import daily reports shared via WhatsApp"
  task whatsapp_reports: :environment do
    reports = [
      {
        code: "DUKE",
        date: "2026-08-19",
        visited: 15,
        onboarded: 4,
        route: "kenol",
        challenges: <<~MSG.chomp,
          - App keeps refreshing, hence disruption during ads upload. Please enable camera capture.
          - Hardware sellers hard to crack and rejection by sellers is noticeable.
          - When can I be provided credit? I need to use bundles during onboarding.
        MSG
        notes: nil
      },
      {
        code: "ANNA",
        date: "2026-08-19",
        visited: 17,
        onboarded: 2,
        route: "Kondele/Migosi, KISUMU",
        challenges: <<~MSG.chomp,
          Most businesses were hesitant, mostly the big hardwares or sellers. The older sellers had trust issues, with some requesting time to think over it.
        MSG
        notes: nil
      },
      {
        code: "ADE",
        date: "2026-08-19",
        visited: 0,
        onboarded: 5,
        route: "Rongai, Tumaini Center",
        challenges: <<~MSG.chomp,
          - Airtime constraints. Limited airtime made it challenging to consistently reach and follow up with prospective sellers. Additional airtime support would help improve communication and seller onboarding.
          - There was a power cut which made most sellers close their businesses early.
        MSG
        notes: nil
      },
      {
        code: "ANNA",
        date: "2026-08-20",
        visited: 0,
        onboarded: 1,
        route: "Carwash/Migosi Road, KISUMU",
        challenges: <<~MSG.chomp,
          Reception is not too good. Most do not embrace digital marketing, though every day is a learning day on the right target.
        MSG
        notes: nil
      },
      {
        code: "DUKE",
        date: "2026-08-20",
        visited: 0,
        onboarded: 1,
        route: "kenol",
        challenges: <<~MSG.chomp,
          - Welders have no smartphone.
          - Some have forgotten passwords of emails; navigation is difficult.
        MSG
        notes: nil
      },
      {
        code: "ADE",
        date: "2026-08-20",
        visited: 0,
        onboarded: 3,
        route: "Rongai, Maasai lodge rd",
        challenges: <<~MSG.chomp,
          Most sellers were complaining of the online presence of the platform. They feel it is not satisfying enough especially those who want to do research before joining the platform.
        MSG
        notes: nil
      },
      {
        code: "DUKE",
        date: "2026-08-21",
        visited: 0,
        onboarded: 0,
        route: "Sabasaba",
        challenges: <<~MSG.chomp,
          Sellers tend to be shy away or cautious when you ask for emails, but phone numbers are easy.
        MSG
        notes: "Has prospective clients"
      },
      {
        code: "DUKE",
        date: "2026-08-24",
        visited: 0,
        onboarded: 2,
        route: "kenol & Kimworori",
        challenges: <<~MSG.chomp,
          - Clients hesitant to join the platform but gave out phone numbers - will follow up.
          - Some thought it is a con and company-self benefiting initiative like how jiji did to them.
        MSG
        notes: nil
      },
      {
        code: "ADE",
        date: "2026-08-24",
        visited: 0,
        onboarded: 4,
        route: "Rongai, Olekasasi and Maasai lodge",
        challenges: <<~MSG.chomp,
          Airtime to follow up with leads but hoping it will be sorted soon.
        MSG
        notes: nil
      }
    ]

    imported = 0
    skipped = 0
    failed = 0

    reports.each do |r|
      sales_user = SalesUser
        .joins(:carbon_codes)
        .find_by(carbon_codes: { code: r[:code] })

      unless sales_user
        puts "[WARN] No sales user found for code #{r[:code]}. Skipping #{r[:date]}."
        skipped += 1
        next
      end

      report_date = Date.parse(r[:date])

      report = SalesDailyReport.find_or_initialize_by(
        sales_user_id: sales_user.id,
        report_date: report_date
      )

      if report.persisted?
        puts "[INFO] Report already exists for #{r[:code]} on #{r[:date]}. Updating."
      end

      report.assign_attributes(
        route_areas: r[:route],
        businesses_visited: r[:visited],
        businesses_onboarded: r[:onboarded],
        challenges: r[:challenges],
        notes: r[:notes],
        categories: [],
        ai_summary: nil,
        sentiment: nil,
        urgency: nil,
        action_items: [],
        verified_by_manager: false
      )

      if report.save
        puts "[OK] Imported report for #{r[:code]} on #{r[:date]}."
        imported += 1
      else
        puts "[ERROR] Failed to import report for #{r[:code]} on #{r[:date]}: #{report.errors.full_messages.join(', ')}"
        failed += 1
      end
    end

    puts "\nDone: #{imported} imported, #{skipped} skipped, #{failed} failed."
  end
end
