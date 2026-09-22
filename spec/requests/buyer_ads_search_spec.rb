require 'rails_helper'

RSpec.describe 'Buyer Ads Search', type: :request do
  let(:category) { Category.create!(name: 'Tools & Hardware') }
  let(:subcategory) { Subcategory.create!(name: 'Hand Tools', category_id: category.id) }

  def create_seller(enterprise_name:, uid:)
    Seller.create!(
      fullname: enterprise_name,
      email: "#{uid}@example.com",
      enterprise_name: enterprise_name,
      provider: 'google',
      uid: uid
    )
  end

  def create_ad(seller:, title:)
    seller.ads.create!(
      title: title,
      description: 'Quality item for sale',
      price: 100,
      brand: 'TestBrand',
      manufacturer: 'TestMfg',
      category: category,
      subcategory: subcategory,
      condition: 'brand_new',
      weight_unit: 'Grams',
      media: ['https://example.com/img.jpg']
    )
  end

  def search_ads(query)
    get '/buyer/ads/search', params: { query: query }
    expect(response).to have_http_status(:ok)
    response.parsed_body['ads']
  end

  describe 'shop name matching' do
    let!(:pangu) { create_seller(enterprise_name: 'Pangu Hardware', uid: 'pangu-uid') }
    let!(:cath) { create_seller(enterprise_name: 'Cath Mash Technologies', uid: 'cath-uid') }

    it 'returns the products of a shop whose full name is searched' do
      create_ad(seller: pangu, title: 'Heavy Duty Wrench')
      create_ad(seller: pangu, title: 'Pipe Wrench 18in')

      ads = search_ads('Pangu Hardware')

      expect(ads).not_to be_empty
      expect(ads.map { |ad| ad['enterprise_name'] }).to all(eq('Pangu Hardware'))
    end

    it 'matches a distinctive partial shop-name token' do
      create_ad(seller: pangu, title: 'Ball Bearing Set')

      ads = search_ads('pangu')

      expect(ads).not_to be_empty
      expect(ads.map { |ad| ad['enterprise_name'] }).to all(eq('Pangu Hardware'))
    end

    it 'matches a multi-word subset of the shop name' do
      create_ad(seller: cath, title: 'Smartphone X10')

      ads = search_ads('cath mash')

      expect(ads.map { |ad| ad['enterprise_name'] }).to include('Cath Mash Technologies')
    end

    it 'matches case-insensitively and ignores punctuation' do
      create_ad(seller: pangu, title: 'Claw Hammer')

      ads = search_ads('PANGU, hardware!!')

      expect(ads.map { |ad| ad['enterprise_name'] }).to include('Pangu Hardware')
    end

    it 'tolerates small typos in the shop name' do
      create_ad(seller: pangu, title: 'Bench Vise')

      ads = search_ads('panguu')

      expect(ads.map { |ad| ad['enterprise_name'] }).to include('Pangu Hardware')
    end

    it 'ranks the matched shop products at the top of the results' do
      create_ad(seller: pangu, title: 'Hex Bolt M8')
      rival = create_seller(enterprise_name: 'Rival Tools Mart', uid: 'rival-uid')
      create_ad(seller: rival, title: 'Pangu Special Drill')

      ads = search_ads('pangu')

      expect(ads.first['enterprise_name']).to eq('Pangu Hardware')
    end

    it 'does not leak unrelated shop products into a shop-name query' do
      create_ad(seller: pangu, title: 'Pliers Set')
      other = create_seller(enterprise_name: 'Zed Wholesalers', uid: 'zed-uid')
      create_ad(seller: other, title: 'Garden Hose Reel')

      ads = search_ads('pangu')

      expect(ads.map { |ad| ad['enterprise_name'] }).not_to include('Zed Wholesalers')
    end
  end

  describe 'generic token guard' do
    it 'does not flood results with shops matching only generic name tokens' do
      generic_shop = create_seller(enterprise_name: 'Nairobi Hardware Supplies', uid: 'nhs-uid')
      create_ad(seller: generic_shop, title: 'Adjustable Spanner')

      ads = search_ads('hardware')

      expect(ads.map { |ad| ad['enterprise_name'] }).not_to include('Nairobi Hardware Supplies')
    end
  end

  describe 'product search regression' do
    it 'still returns plain title matches for product queries' do
      seller = create_seller(enterprise_name: 'Rival Tools Mart', uid: 'rival-uid')
      create_ad(seller: seller, title: 'Cordless Angle Grinder')

      ads = search_ads('cordless angle grinder')

      expect(ads.map { |ad| ad['title'] }).to include('Cordless Angle Grinder')
    end
  end
end
