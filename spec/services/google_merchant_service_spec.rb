# spec/services/google_merchant_service_spec.rb
require 'rails_helper'

RSpec.describe GoogleMerchantService, type: :service do
  let(:seller) do
    Seller.create!(
      fullname: 'Test Seller',
      email: 'merchant-seller@example.com',
      provider: 'google',
      uid: 'merchant-spec-uid'
    )
  end
  let(:category) { Category.create!(name: 'Electronics') }
  let(:subcategory) { Subcategory.create!(name: 'Phones', category_id: category.id) }

  let(:valid_ad) do
    seller.ads.create!(
      title: 'Test Product',
      description: 'Test Description',
      price: 100.0,
      brand: 'Test Brand',
      manufacturer: 'Test Manufacturer',
      category: category,
      subcategory: subcategory,
      condition: 'brand_new',
      media: ['https://example.com/image.jpg'],
      flagged: false,
      deleted: false
    )
  end

  let(:invalid_ad) do
    seller.ads.new(
      title: '',
      description: '',
      price: 0,
      category: category,
      subcategory: subcategory,
      media: [],
      flagged: false,
      deleted: false
    )
  end

  describe '.sync_ad' do
    it 'returns true when the API accepts a valid ad' do
      allow(described_class).to receive(:send_to_merchant_api)
        .and_return(double(success?: true, body: 'ok'))

      expect(described_class.sync_ad(valid_ad)).to be true
    end

    it 'returns false when the API rejects the ad' do
      allow(described_class).to receive(:send_to_merchant_api)
        .and_return(double(success?: false, body: 'api error'))

      expect(described_class.sync_ad(valid_ad)).to be false
    end

    it 'returns false for an invalid ad without calling the API' do
      allow(described_class).to receive(:send_to_merchant_api)

      expect(described_class.sync_ad(invalid_ad)).to be false
      expect(described_class).not_to have_received(:send_to_merchant_api)
    end

    it 'returns false for nil ad' do
      expect(described_class.sync_ad(nil)).to be false
    end

    it 'returns false for an ad from a blocked seller' do
      seller.update!(blocked: true)
      allow(described_class).to receive(:send_to_merchant_api)

      expect(described_class.sync_ad(valid_ad)).to be false
      expect(described_class).not_to have_received(:send_to_merchant_api)
    end
  end

  describe '.sync_all_active_ads' do
    it 'syncs only ads from premium sellers' do
      tier = Tier.create!(id: 4, name: 'Premium', ads_limit: 100)
      SellerTier.create!(seller: seller, tier: tier, duration_months: 12, expires_at: 1.year.from_now)
      valid_ad
      invalid_ad.save!(validate: false)

      allow(described_class).to receive(:sync_ad).and_return(true)

      result = described_class.sync_all_active_ads
      expect(result[:success]).to eq(2)
      expect(result[:failed]).to eq(0)
    end

    it 'skips sellers without a premium tier' do
      valid_ad

      allow(described_class).to receive(:sync_ad).and_return(true)

      expect(described_class.sync_all_active_ads[:success]).to eq(0)
    end
  end

  describe '.build_product_data' do
    it 'builds the correct product data structure' do
      product_data = described_class.build_product_data(valid_ad)

      expect(product_data[:offerId]).to eq("carbon_cube_#{valid_ad.id}")
      expect(product_data[:contentLanguage]).to eq('en')
      expect(product_data[:feedLabel]).to eq('carbon_cube_feed')

      attrs = product_data[:productAttributes]
      expect(attrs[:title]).to eq('Test Product')
      expect(attrs[:description]).to eq('Test Description')
      expect(attrs[:link]).to eq(valid_ad.product_url)
      expect(attrs[:image_link]).to eq('https://example.com/image.jpg')
      expect(attrs[:availability]).to eq('in stock')
      expect(attrs[:price]).to eq({ value: 100.0, currency: 'KES' })
      expect(attrs[:condition]).to eq('new')
      expect(attrs[:brand]).to eq('Test Brand')
    end
  end

  describe '.normalize_condition' do
    it 'maps ad conditions to Google Merchant conditions' do
      expect(described_class.normalize_condition('brand_new')).to eq('new')
      expect(described_class.normalize_condition('x_japan')).to eq('new')
      expect(described_class.normalize_condition('second_hand')).to eq('used')
      expect(described_class.normalize_condition('refurbished')).to eq('refurbished')
      expect(described_class.normalize_condition('unknown')).to eq('new')
      expect(described_class.normalize_condition(nil)).to eq('new')
    end
  end

  describe '.normalize_availability' do
    it 'maps availability statuses to Google Merchant values' do
      expect(described_class.normalize_availability('IN_STOCK')).to eq('in stock')
      expect(described_class.normalize_availability('OUT_OF_STOCK')).to eq('out of stock')
      expect(described_class.normalize_availability('PREORDER')).to eq('preorder')
      expect(described_class.normalize_availability(nil)).to eq('in stock')
    end
  end

  describe '.create_slug' do
    it 'creates a URL-friendly slug from a title' do
      expect(described_class.create_slug('Test Product!')).to eq('test-product')
      expect(described_class.create_slug(nil)).to be_nil
    end
  end

  describe 'Ad#product_url' do
    it 'generates a slugged ad URL using the canonical stored slug' do
      expect(valid_ad.product_url).to eq("https://carboncube-ke.com/ads/#{valid_ad.slug}?id=#{valid_ad.id}")
      expect(valid_ad.slug).to eq("test-product-#{valid_ad.id}")
    end
  end
end
