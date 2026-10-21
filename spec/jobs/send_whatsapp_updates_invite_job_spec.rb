# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SendWhatsappUpdatesInviteJob, type: :job do
  include ActiveJob::TestHelper

  let(:county) { County.first || County.create!(name: 'Nairobi', capital: 'Nairobi', county_code: '047') }
  let(:sub_county) { SubCounty.first || SubCounty.create!(name: 'Westlands', sub_county_code: '047-1', county: county) }

  def create_seller(attrs = {})
    unique_suffix = SecureRandom.hex(4)
    Seller.create!({
      fullname: "Seller #{unique_suffix}",
      enterprise_name: "Shop #{unique_suffix}",
      email: "seller_#{unique_suffix}@example.com",
      phone_number: "07#{rand(10000000..99999999)}",
      county_id: county.id,
      sub_county_id: sub_county.id,
      location: 'Westlands, Nairobi',
      password: 'Password123!',
      password_confirmation: 'Password123!'
    }.merge(attrs))
  end

  describe '#perform' do
    describe 'initial invite (T+2d)' do
      it 'delivers email invite to users created ~2 days ago' do
        seller = create_seller
        seller.update_columns(created_at: 55.hours.ago)

        expect do
          described_class.new.perform(dry_run: false)
        end.to change { ActionMailer::Base.deliveries.count }.by(1)

        expect(Notification.where(recipient: seller, title: described_class::INVITE_NOTIFICATION_TITLE)).to exist
      end

      it 'skips users who are already engaged on WhatsApp' do
        seller = create_seller(whatsapp_opt_in_source: 'whatsapp_keyword')
        seller.update_columns(created_at: 55.hours.ago)

        expect do
          stats = described_class.new.perform(dry_run: false)
          expect(stats[:initial_skipped_engaged]).to eq(1)
        end.not_to(change { ActionMailer::Base.deliveries.count })
      end

      it 'skips users who have already received the initial invite' do
        seller = create_seller
        seller.update_columns(created_at: 55.hours.ago)

        Notification.create!(
          recipient: seller,
          title: described_class::INVITE_NOTIFICATION_TITLE,
          body: 'Invite',
          data: {}
        )

        expect do
          stats = described_class.new.perform(dry_run: false)
          expect(stats[:initial_skipped_duplicate]).to eq(1)
        end.not_to(change { ActionMailer::Base.deliveries.count })
      end

      it 'skips users outside the 48h-72h window' do
        recent = create_seller
        recent.update_columns(created_at: 10.hours.ago)

        expect do
          stats = described_class.new.perform(dry_run: false)
          expect(stats[:initial_eligible]).to eq(0)
        end.not_to(change { ActionMailer::Base.deliveries.count })
      end
    end

    describe 'follow-up reminder (T+5d)' do
      it 'sends reminder to users who received initial invite ~3 days ago and have not engaged' do
        seller = create_seller
        seller.update_columns(created_at: 6.days.ago)

        notif = Notification.create!(
          recipient: seller,
          title: described_class::INVITE_NOTIFICATION_TITLE,
          body: 'Invite',
          data: {}
        )
        notif.update_columns(created_at: 3.5.days.ago)

        expect do
          described_class.new.perform(dry_run: false)
        end.to change { ActionMailer::Base.deliveries.count }.by(1)

        expect(Notification.where(recipient: seller, title: described_class::REMINDER_NOTIFICATION_TITLE)).to exist
      end

      it 'skips reminder if user engaged on WhatsApp after initial invite' do
        seller = create_seller(whatsapp_opt_in_source: 'whatsapp_keyword')
        seller.update_columns(created_at: 6.days.ago)

        notif = Notification.create!(
          recipient: seller,
          title: described_class::INVITE_NOTIFICATION_TITLE,
          body: 'Invite',
          data: {}
        )
        notif.update_columns(created_at: 3.5.days.ago)

        expect do
          stats = described_class.new.perform(dry_run: false)
          expect(stats[:reminder_skipped_engaged]).to eq(1)
        end.not_to(change { ActionMailer::Base.deliveries.count })
      end
    end
  end
end
