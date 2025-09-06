require "test_helper"

class SellersControllerTest < ActionDispatch::IntegrationTest
  test "should assign premium tier for 2025 registrations" do
    # Mock the current year to be 2025
    Date.stub :current, Date.new(2025, 6, 15) do
      seller_params = {
        seller: {
          fullname: "Test Seller",
          email: "test@example.com",
          phone_number: "0712345678",
          enterprise_name: "Test Enterprise",
          location: "Nairobi",
          county_id: 1,
          sub_county_id: 1,
          age_group_id: 1,
          password: "password123",
          password_confirmation: "password123"
        }
      }
      
      post "/seller/signup", params: seller_params
      
      assert_response :created
      
      # Check that seller was created
      seller = Seller.find_by(email: "test@example.com")
      assert_not_nil seller
      
      # Check that premium tier was assigned
      seller_tier = seller.seller_tier
      assert_not_nil seller_tier
      assert_equal 4, seller_tier.tier_id # Premium tier
      # Should be 6 months from June 15 to December 31, 2025
      expected_months = ((Date.new(2025, 12, 31) - Date.new(2025, 6, 15)) / 30.44).ceil
      assert_equal expected_months, seller_tier.duration_months
    end
  end
  
  test "should assign free tier for non-2025 registrations" do
    # Mock the current year to be 2024
    Date.stub :current, Date.new(2024, 6, 15) do
      seller_params = {
        seller: {
          fullname: "Test Seller 2024",
          email: "test2024@example.com",
          phone_number: "0712345679",
          enterprise_name: "Test Enterprise 2024",
          location: "Nairobi",
          county_id: 1,
          sub_county_id: 1,
          age_group_id: 1,
          password: "password123",
          password_confirmation: "password123"
        }
      }
      
      post "/seller/signup", params: seller_params
      
      assert_response :created
      
      # Check that seller was created
      seller = Seller.find_by(email: "test2024@example.com")
      assert_not_nil seller
      
      # Check that free tier was assigned
      seller_tier = seller.seller_tier
      assert_not_nil seller_tier
      assert_equal 1, seller_tier.tier_id # Free tier
      assert_equal 0, seller_tier.duration_months # Free tier has 0 duration
    end
  end
end
