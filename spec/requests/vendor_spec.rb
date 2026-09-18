# spec/requests/vendor_spec.rb
require 'rails_helper'

RSpec.describe 'Seller Management', type: :request do
  let(:signup_params) do
    {
      seller: {
        fullname: 'John Doe',
        email: 'john.doe@example.com',
        phone_number: '0712345678',
        password: 'securepassword1',
        password_confirmation: 'securepassword1'
      }
    }
  end

  let(:seller) do
    Seller.create!(
      fullname: 'John Doe',
      email: 'john.doe@example.com',
      provider: 'google',
      uid: 'vendor-spec-uid',
      password: 'securepassword1',
      password_confirmation: 'securepassword1'
    )
  end

  let(:auth_headers) do
    token = JsonWebToken.encode(seller_id: seller.id, email: seller.email, role: 'seller')
    { 'Authorization' => "Bearer #{token}" }
  end

  describe 'Seller Signup' do
    it 'validates the signup details when no OTP is provided' do
      post '/seller/signup', params: signup_params

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['success']).to be(true)
    end

    it 'returns 422 when required fields are missing' do
      post '/seller/signup', params: { seller: { email: 'john.doe@example.com' } }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 422 when the email is already in use' do
      seller # creates the seller with the same email

      post '/seller/signup', params: signup_params

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['errors']).to include('Email is already in use')
    end
  end

  describe 'Seller Login' do
    before { seller }

    it 'logs in with valid credentials' do
      post '/auth/login', params: { email: 'john.doe@example.com', password: 'securepassword1' }

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['token']).to be_present
      expect(body['user']['role']).to eq('Seller')
    end

    it 'rejects invalid credentials' do
      post '/auth/login', params: { email: 'john.doe@example.com', password: 'wrong-password' }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'Product Management' do
    let(:category) { Category.create!(name: 'Tools') }
    let(:subcategory) { Subcategory.create!(name: 'Power Tools', category_id: category.id) }

    before do
      tier = Tier.create!(name: 'Pro', ads_limit: 50)
      SellerTier.create!(seller: seller, tier: tier, duration_months: 12, expires_at: 1.year.from_now)
    end

    it 'creates a product' do
      post '/seller/ads', headers: auth_headers, params: ad_params

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['title']).to eq('New Product')
    end

    it 'updates a product' do
      post '/seller/ads', headers: auth_headers, params: ad_params
      product_id = response.parsed_body['id']

      put "/seller/ads/#{product_id}", headers: auth_headers, params: {
        ad: { title: 'Updated Product', description: 'This is an updated product' }
      }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['title']).to eq('Updated Product')
    end

    it 'deletes a product' do
      post '/seller/ads', headers: auth_headers, params: ad_params
      product_id = response.parsed_body['id']

      delete "/seller/ads/#{product_id}", headers: auth_headers

      expect(response).to have_http_status(:no_content)
    end
  end

  describe 'Analytics' do
    it 'views seller analytics' do
      get '/seller/analytics', headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['tier_id']).to be_present
    end
  end

  def ad_params
    {
      ad: {
        title: 'New Product',
        description: 'This is a new product',
        category_id: category.id,
        subcategory_id: subcategory.id,
        price: 99.99,
        stock_quantity: 100,
        brand: 'Brand Name',
        manufacturer: 'Manufacturer Name',
        condition: 'brand_new'
      }
    }
  end
end
