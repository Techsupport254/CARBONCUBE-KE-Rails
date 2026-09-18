require 'rails_helper'

RSpec.describe 'Seller Catalog', type: :request do
  let(:seller) do
    Seller.create!(
      fullname: 'Catalog Seller',
      email: 'catalog-seller@example.com',
      provider: 'google',
      uid: 'catalog-spec-uid',
      enterprise_name: 'Catalog Enterprise'
    )
  end
  let(:category) { Category.create!(name: 'Tools') }
  let(:subcategory) { Subcategory.create!(name: 'Power Tools', category_id: category.id) }
  let(:token) { JsonWebToken.encode(seller_id: seller.id, email: seller.email, role: 'seller') }

  let!(:ad) do
    seller.ads.create!(
      title: 'Catalog Ad',
      description: 'An ad in the catalog',
      price: 150,
      brand: 'TestBrand',
      manufacturer: 'TestMfg',
      category: category,
      subcategory: subcategory,
      condition: 'brand_new',
      sku: 'SKU-001',
      units_per_pack: 12,
      stock_quantity: 40
    )
  end

  describe 'GET /seller/catalog?format=csv' do
    it 'includes sku, units_per_pack and stock_quantity columns' do
      get '/seller/catalog', params: { token: token, format: 'csv' }

      expect(response).to have_http_status(:ok)
      csv = CSV.parse(response.body, headers: true)
      expect(csv.headers).to include('SKU', 'Units/Pack', 'Stock Qty')

      row = csv.first
      expect(row['SKU']).to eq('SKU-001')
      expect(row['Title']).to eq('Catalog Ad')
      expect(row['Units/Pack']).to eq('12')
      expect(row['Stock Qty']).to eq('40')
    end
  end

  describe 'GET /seller/catalog (HTML)' do
    it 'renders sku, pack size and the stock badge' do
      get '/seller/catalog', params: { token: token }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('SKU: SKU-001')
      expect(response.body).to include('12 per pack')
      expect(response.body).to include('In Stock: 40')
    end

    it 'shows Out of Stock when a tracked ad reaches zero' do
      ad.update!(stock_quantity: 0)

      get '/seller/catalog', params: { token: token }

      expect(response.body).to include('Out of Stock')
    end
  end

  it 'returns 401 without a token' do
    get '/seller/catalog'

    expect(response).to have_http_status(:unauthorized)
  end
end
