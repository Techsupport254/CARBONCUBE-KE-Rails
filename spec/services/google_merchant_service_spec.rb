# spec/services/google_merchant_service_spec.rb
require 'rails_helper'

RSpec.describe GoogleMerchantService, type: :service do
  let(:seller) { create(:seller, blocked: false, deleted: false) }
  let(:category) { create(:category) }
  let(:subcategory) { create(:subcategory, category: category) }
  
  let(:valid_ad) do
    create(:ad,
           seller: seller,
           category: category,
           subcategory: subcategory,
           title: 'Test Product',
           description: 'Test Description',
           price: 100.0,
           brand: 'Test Brand',
           condition: 'brand_new',
           media: ['https://example.com/image.jpg'],
           flagged: false,
           deleted: false)
  end
  
  let(:invalid_ad) do
    create(:ad,
           seller: seller,
           category: category,
           subcategory: subcategory,
           title: '',
           description: '',
           price: 0,
           media: [],
           flagged: false,
           deleted: false)
  end

  describe '.sync_ad' do
    context 'with valid ad' do
      it 'returns true for valid ad' do
        expect(GoogleMerchantService.sync_ad(valid_ad)).to be_truthy
      end
    end

    context 'with invalid ad' do
      it 'returns false for invalid ad' do
        expect(GoogleMerchantService.sync_ad(invalid_ad)).to be_falsey
      end
    end

    context 'with nil ad' do
      it 'returns false for nil ad' do
        expect(GoogleMerchantService.sync_ad(nil)).to be_falsey
      end
    end
  end

  describe '.sync_all_active_ads' do
    before do
      valid_ad
      invalid_ad
    end

    it 'syncs only valid ads' do
      result = GoogleMerchantService.sync_all_active_ads
      expect(result[:success]).to be > 0
    end
  end

  describe '#build_product_data' do
    it 'builds correct product data structure' do
      service = GoogleMerchantService.new
      product_data = service.send(:build_product_data, valid_ad)
      
      expect(product_data[:offerId]).to eq(valid_ad.id.to_s)
      expect(product_data[:contentLanguage]).to eq('en')
      expect(product_data[:feedLabel]).to eq('primary')
      expect(product_data[:productAttributes][:title]).to eq('Test Product')
      expect(product_data[:productAttributes][:description]).to eq('Test Description')
      expect(product_data[:productAttributes][:availability]).to eq('IN_STOCK')
      expect(product_data[:productAttributes][:condition]).to eq('NEW')
      expect(product_data[:productAttributes][:brand]).to eq('Test Brand')
    end
  end

  describe '#generate_product_url' do
    it 'generates correct product URL' do
      service = GoogleMerchantService.new
      url = service.send(:generate_product_url, valid_ad)
      
      expect(url).to include('carboncube-ke.com')
      expect(url).to include('/ads/')
      expect(url).to include("id=#{valid_ad.id}")
    end
  end

  describe '#map_condition' do
    it 'maps condition correctly' do
      service = GoogleMerchantService.new
      
      expect(service.send(:map_condition, 'brand_new')).to eq('NEW')
      expect(service.send(:map_condition, 'second_hand')).to eq('USED')
      expect(service.send(:map_condition, 'refurbished')).to eq('REFURBISHED')
      expect(service.send(:map_condition, 'unknown')).to eq('NEW')
    end
  end
end
