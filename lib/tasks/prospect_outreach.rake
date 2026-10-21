# frozen_string_literal: true

namespace :prospect_outreach do
  desc "Import prospects from a CSV (Usage: rake 'prospect_outreach:import[path,list]')"
  task :import, %i[path list] => :environment do |_t, args|
    path = args[:path].presence or abort "Usage: rake 'prospect_outreach:import[path]'"
    list = args[:list].presence || 'main'

    stats = { created: 0, skipped_no_email: 0, duplicate: 0, invalid: 0 }
    CSV.foreach(path, headers: true) do |row|
      email = row['email'].to_s.strip.downcase

      if email.blank?
        name = row['business_name'].to_s.strip
        unless name.present? && OutreachProspect.exists?(['lower(business_name) = ?', name.downcase])
          prospect = OutreachProspect.new
          assign_row(prospect, row, list)
          prospect.valid? ? prospect.save! : stats[:invalid] += 1
        end
        stats[:skipped_no_email] += 1
        next
      end

      if OutreachProspect.exists?(['lower(email) = ?', email])
        stats[:duplicate] += 1
        next
      end

      prospect = OutreachProspect.new(email: email)
      assign_row(prospect, row, list)
      if prospect.valid?
        prospect.save!
        stats[:created] += 1
      else
        stats[:invalid] += 1
      end
    end

    puts "Import from #{path}:"
    puts "  created:            #{stats[:created]}"
    puts "  already in queue:   #{stats[:duplicate]}"
    puts "  phone-only (saved): #{stats[:skipped_no_email]}"
    puts "  invalid rows:       #{stats[:invalid]}"
  end

  desc 'Import the prospect CSVs bundled in db/prospect_lists (Usage: rake prospect_outreach:import_bundled)'
  task import_bundled: :environment do
    {
      'db/prospect_lists/nairobi-seller-prospects.csv' => 'main',
      'db/prospect_lists/backup-leads.csv' => 'backup'
    }.each do |rel, list|
      Rake::Task['prospect_outreach:import'].reenable
      Rake::Task['prospect_outreach:import'].invoke(Rails.root.join(rel).to_s, list)
    end
  end

  desc 'Show outreach queue status (Usage: rake prospect_outreach:stats)'
  task stats: :environment do
    puts OutreachProspect.group(:status).order(:status).count
    puts "Total: #{OutreachProspect.count}"
  end

  desc 'Send one test email (Usage: rake \'prospect_outreach:preview[you@x.com]\')'
  task :preview, %i[to] => :environment do |_t, args|
    to = args[:to].presence or abort "Usage: rake 'prospect_outreach:preview[you@x.com]'"
    p = OutreachProspect.emailable.first ||
        OutreachProspect.new(business_name: 'Sample Motors', area: 'Kirinyaga Rd',
                             category: 'Automotive Parts & Accessories',
                             subcategory: 'Automotive Spare Parts')
    mail = ProspectMailer.with(to: to, business_name: p.business_name, area: p.area,
                               category: p.category, subcategory: p.subcategory).cold_outreach
    mail.deliver_now
    puts "Sent preview to #{to} (message_id: #{mail.message_id})"
  end

  desc 'Immediately queue N pending prospect emails, staggered (Usage: rake \'prospect_outreach:send_batch[20]\')'
  task :send_batch, %i[limit] => :environment do |_t, args|
    limit = (args[:limit].presence || '50').to_i
    ids = OutreachProspect.emailable.order(:id).limit(limit).pluck(:id)
    abort 'No pending prospects' if ids.empty?

    spacing = 120 * 60 / [ids.size, 1].max
    ids.each_with_index do |id, i|
      SendProspectEmailJob.set(wait: (i * spacing + rand(0..45)).seconds).perform_later(id)
    end
    puts "Queued #{ids.size} prospect emails, spread over ~2h"
  end

  private

  def assign_row(prospect, row, list)
    prospect.assign_attributes(
      business_name: row['business_name'].to_s.strip,
      phone: row['phone'].to_s.strip.presence,
      area: row['area'].to_s.strip.presence,
      category: row['category'].to_s.strip.presence,
      subcategory: row['subcategory'].to_s.strip.presence,
      website: row['website'].to_s.strip.presence,
      source_url: row['source_url'].to_s.strip.presence,
      source_type: row['source_type'].to_s.strip.presence,
      list_type: list
    )
  end
end
