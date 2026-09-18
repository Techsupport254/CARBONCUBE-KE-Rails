require 'rails_helper'

RSpec.describe 'Seller Ads', type: :request do
  let(:seller) do
    Seller.create!(
      fullname: 'Test Seller',
      email: 'seller@example.com',
      provider: 'google',
      uid: 'seller-uid-1'
    )
  end
  let(:category) { Category.create!(name: 'Electronics') }
  let(:subcategory) { Subcategory.create!(name: 'Phones', category_id: category.id) }
  let(:auth_headers) do
    token = JsonWebToken.encode(seller_id: seller.id, email: seller.email, role: 'seller')
    { 'Authorization' => "Bearer #{token}" }
  end
  let(:ad) do
    seller.ads.create!(
      title: 'Test Ad',
      description: 'A test ad',
      price: 100,
      brand: 'TestBrand',
      manufacturer: 'TestMfg',
      category: category,
      subcategory: subcategory,
      condition: 'brand_new',
      weight_unit: 'Grams'
    )
  end

  describe 'POST /seller/ads' do
    before do
      tier = Tier.create!(name: 'Pro', ads_limit: 50)
      SellerTier.create!(seller: seller, tier: tier, duration_months: 12, expires_at: 1.year.from_now)
    end

    it 'creates an ad with sku, units_per_pack and stock_quantity' do
      post '/seller/ads', headers: auth_headers, params: {
        ad: {
          title: 'Stocked Ad',
          description: 'Ad with inventory fields',
          price: 250,
          brand: 'TestBrand',
          manufacturer: 'TestMfg',
          category_id: category.id,
          subcategory_id: subcategory.id,
          condition: 'brand_new',
          sku: 'SKU-123',
          units_per_pack: 12,
          stock_quantity: 40
        }
      }

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body['sku']).to eq('SKU-123')
      expect(body['units_per_pack']).to eq(12)
      expect(body['stock_quantity']).to eq(40)
    end
  end

  describe 'PUT /seller/ads/:id' do
    it 'updates sku, units_per_pack and stock_quantity' do
      put "/seller/ads/#{ad.id}", headers: auth_headers, params: {
        ad: {
          sku: 'SKU-UPDATED',
          units_per_pack: 6,
          stock_quantity: 15
        }
      }

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['sku']).to eq('SKU-UPDATED')
      expect(body['units_per_pack']).to eq(6)
      expect(body['stock_quantity']).to eq(15)
    end
  end

  describe 'PATCH /seller/ads/:id/stock' do
    it 'sets stock_quantity to an absolute value' do
      patch "/seller/ads/#{ad.id}/stock", headers: auth_headers, params: { stock_quantity: 25 }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['stock_quantity']).to eq(25)
      expect(ad.reload.stock_quantity).to eq(25)
    end

    it 'applies a positive adjustment to the current quantity' do
      ad.update!(stock_quantity: 10)

      patch "/seller/ads/#{ad.id}/stock", headers: auth_headers, params: { adjustment: 5 }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['stock_quantity']).to eq(15)
    end

    it 'applies a negative adjustment to the current quantity' do
      ad.update!(stock_quantity: 10)

      patch "/seller/ads/#{ad.id}/stock", headers: auth_headers, params: { adjustment: -4 }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['stock_quantity']).to eq(6)
    end

    it 'treats a nil stock_quantity as 0 when adjusting' do
      patch "/seller/ads/#{ad.id}/stock", headers: auth_headers, params: { adjustment: 3 }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['stock_quantity']).to eq(3)
    end

    it 'returns 422 when the result would be negative' do
      ad.update!(stock_quantity: 2)

      patch "/seller/ads/#{ad.id}/stock", headers: auth_headers, params: { adjustment: -5 }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to eq('Stock quantity cannot be negative')
      expect(ad.reload.stock_quantity).to eq(2)
    end

    it 'returns 422 when neither stock_quantity nor adjustment is provided' do
      patch "/seller/ads/#{ad.id}/stock", headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to eq('Provide stock_quantity or adjustment')
    end

    it "returns 404 for another seller's ad" do
      other_seller = Seller.create!(
        fullname: 'Other Seller',
        email: 'other@example.com',
        provider: 'google',
        uid: 'seller-uid-2'
      )
      other_ad = other_seller.ads.create!(
        title: 'Other Ad',
        description: 'Not yours',
        price: 50,
        brand: 'Brand',
        manufacturer: 'Mfg',
        category: category,
        subcategory: subcategory,
        condition: 'brand_new',
        weight_unit: 'Grams',
        stock_quantity: 7
      )

      patch "/seller/ads/#{other_ad.id}/stock", headers: auth_headers, params: { stock_quantity: 1 }

      expect(response).to have_http_status(:not_found)
      expect(other_ad.reload.stock_quantity).to eq(7)
    end
  end

  describe 'POST /seller/ads/batch_create' do
    it 'creates ads with sku, units_per_pack and stock_quantity' do
      post '/seller/ads/batch_create', headers: auth_headers, params: {
        ads: [
          {
            title: 'Batch Ad',
            description: 'Created in bulk',
            price: 80,
            brand: 'TestBrand',
            manufacturer: 'TestMfg',
            category_id: category.id,
            subcategory_id: subcategory.id,
            condition: 'brand_new',
            sku: 'BATCH-1',
            units_per_pack: 4,
            stock_quantity: 30
          }
        ]
      }

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body['created_count']).to eq(1)
      expect(body['created_ads'].first['sku']).to eq('BATCH-1')
      expect(body['created_ads'].first['units_per_pack']).to eq(4)
      expect(body['created_ads'].first['stock_quantity']).to eq(30)
    end

    it 'merges top-level pricing_unit into specifications' do
      post '/seller/ads/batch_create', headers: auth_headers, params: {
        ads: [
          {
            title: 'Priced Ad',
            description: 'Has a pricing unit',
            price: 80,
            brand: 'TestBrand',
            manufacturer: 'TestMfg',
            category_id: category.id,
            subcategory_id: subcategory.id,
            condition: 'brand_new',
            pricing_unit: 'piece'
          }
        ]
      }

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body['created_count']).to eq(1)
      expect(body['failed_count']).to eq(0)
      expect(body['created_ads'].first['specifications']['pricing_unit']).to eq('piece')
    end
  end
end
