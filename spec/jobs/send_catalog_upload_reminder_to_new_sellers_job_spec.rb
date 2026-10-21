# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SendCatalogUploadReminderToNewSellersJob, type: :job do
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

  before do
    ActiveJob::Base.queue_adapter = :test
  end

  describe '#perform' do
    it 'enqueues SendCatalogUploadReminderJob for sellers registered ~1 week ago without ads' do
      seller = create_seller
      seller.update_columns(created_at: 175.hours.ago) # Between 168h and 192h

      expect do
        described_class.new.perform(dry_run: false)
      end.to have_enqueued_job(SendCatalogUploadReminderJob).with(seller.id)
    end

    it 'skips sellers who already have active ads' do
      seller = create_seller
      seller.update_columns(created_at: 175.hours.ago)

      category = Category.first || Category.create!(name: 'Electronics')
      subcategory = Subcategory.first || Subcategory.create!(name: 'Laptops', category: category)

      Ad.create!(
        seller: seller,
        category: category,
        subcategory: subcategory,
        title: 'HP Laptop',
        description: 'Brand new condition',
        brand: 'HP',
        manufacturer: 'HP',
        price: 45000,
        condition: 'brand_new',
        deleted: false
      )

      expect do
        stats = described_class.new.perform(dry_run: false)
        expect(stats[:skipped_has_ads]).to eq(1)
        expect(stats[:queued]).to eq(0)
      end.not_to have_enqueued_job(SendCatalogUploadReminderJob)
    end

    it 'skips sellers who have already received this reminder notification' do
      seller = create_seller
      seller.update_columns(created_at: 175.hours.ago)

      Notification.create!(
        recipient: seller,
        title: SendCatalogUploadReminderJob::NOTIFICATION_TITLE,
        body: 'Reminder',
        data: {}
      )

      expect do
        stats = described_class.new.perform(dry_run: false)
        expect(stats[:skipped_duplicate]).to eq(1)
        expect(stats[:queued]).to eq(0)
      end.not_to have_enqueued_job(SendCatalogUploadReminderJob)
    end

    it 'skips sellers outside the 168h-192h window' do
      recent_seller = create_seller
      recent_seller.update_columns(created_at: 48.hours.ago)

      old_seller = create_seller
      old_seller.update_columns(created_at: 250.hours.ago)

      expect do
        stats = described_class.new.perform(dry_run: false)
        expect(stats[:eligible]).to eq(0)
        expect(stats[:queued]).to eq(0)
      end.not_to have_enqueued_job(SendCatalogUploadReminderJob)
    end

    it 'skips deleted or blocked sellers' do
      deleted_seller = create_seller(deleted: true)
      deleted_seller.update_columns(created_at: 175.hours.ago)

      blocked_seller = create_seller(blocked: true)
      blocked_seller.update_columns(created_at: 175.hours.ago)

      expect do
        stats = described_class.new.perform(dry_run: false)
        expect(stats[:eligible]).to eq(0)
        expect(stats[:queued]).to eq(0)
      end.not_to have_enqueued_job(SendCatalogUploadReminderJob)
    end

    it 'does not enqueue jobs when dry_run: true' do
      seller = create_seller
      seller.update_columns(created_at: 175.hours.ago)

      expect do
        stats = described_class.new.perform(dry_run: true)
        expect(stats[:eligible]).to eq(1)
        expect(stats[:queued]).to eq(1)
      end.not_to have_enqueued_job(SendCatalogUploadReminderJob)
    end
  end
end
