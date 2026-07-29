require "test_helper"

class Admin::SellersControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  def setup
    @admin = Admin.new(
      username: "admin_#{SecureRandom.hex(4)}",
      fullname: "Admin User",
      email: "admin-test-#{SecureRandom.hex(4)}@example.com",
      password: "password123"
    )
    @admin.save(validate: false)

    @seller = Seller.new(
      email: "admin-seller-test-#{SecureRandom.hex(4)}@example.com",
      fullname: "Admin Seller",
      enterprise_name: "Admin Seller Enterprise",
      phone_number: "0712345678",
      location: "Mombasa"
    )
    @seller.save(validate: false)
  end

  test "create_default_branch_for_seller creates a main branch" do
    controller = Admin::SellersController.new
    controller.send(:create_default_branch_for_seller, @seller)

    @seller.reload
    assert_equal 1, @seller.branches.count
    assert @seller.branches.first.is_main_branch
    assert_equal "Mombasa", @seller.branches.first.location
  end
end
