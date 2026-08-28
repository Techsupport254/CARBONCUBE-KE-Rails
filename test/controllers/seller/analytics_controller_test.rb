require "test_helper"

class Seller::AnalyticsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @basic_tier = Tier.find_or_create_by!(name: "Basic", ads_limit: 100)
    @free_tier = Tier.find_or_create_by!(name: "Free", ads_limit: 20)

    @seller = Seller.create!(
      email: "market_test_#{SecureRandom.hex(4)}@example.com",
      phone_number: "07#{SecureRandom.random_number(1_000_000_00).to_s.rjust(8, '0')}",
      fullname: "Market Test Seller"
    )
    SellerTier.create!(seller: @seller, tier: @basic_tier, duration_months: 1)

    @category = Category.find_or_create_by!(name: "Automotive Test #{SecureRandom.hex(4)}")
    @subcategory = Subcategory.find_or_create_by!(name: "Spare Parts Test #{SecureRandom.hex(4)}", category: @category)
    Ad.create!(
      title: "Spark Plug",
      description: "Reliable spark plug",
      brand: "NGK",
      manufacturer: "NGK",
      price: 1000.00,
      weight_unit: "Grams",
      category: @category,
      subcategory: @subcategory,
      seller: @seller
    )
  end

  test "paid seller receives market_intelligence in /seller/analytics" do
    token = JsonWebToken.encode(seller_id: @seller.id, email: @seller.email, role: "seller")
    get "/seller/analytics", headers: { "Authorization" => "Bearer #{token}" }, as: :json

    assert_response :success
    body = response.parsed_body

    assert body["market_intelligence"].present?
    assert body["market_intelligence"]["pricing"].present?
    assert body["market_intelligence"]["most_searched"].is_a?(Array)
    assert_equal @category.name, body["market_intelligence"]["primary_category"]["name"]
  end

  test "free tier does not receive market_intelligence" do
    SellerTier.where(seller: @seller).destroy_all
    SellerTier.create!(seller: @seller, tier: @free_tier, duration_months: 0)

    token = JsonWebToken.encode(seller_id: @seller.id, email: @seller.email, role: "seller")
    get "/seller/analytics", headers: { "Authorization" => "Bearer #{token}" }, as: :json

    assert_response :success
    body = response.parsed_body

    assert_nil body["market_intelligence"]
  end
end
