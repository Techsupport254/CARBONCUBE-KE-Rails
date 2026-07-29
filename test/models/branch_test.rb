require "test_helper"

class BranchTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def setup
    @seller = Seller.new(
      email: "branch-test-#{SecureRandom.hex(4)}@example.com",
      fullname: "Branch Test Seller",
      enterprise_name: "Branch Test Enterprise",
      phone_number: "0712345678",
      location: "Nairobi"
    )
    @seller.save(validate: false)
  end

  test "queues geocoding job after create when coordinates are missing" do
    branch = @seller.branches.create!(
      name: "Main Branch",
      location: "Nairobi",
      is_main_branch: true
    )

    assert branch.latitude.blank?
    assert branch.longitude.blank?
    assert_enqueued_with(job: GeocodeSellersJob, args: [branch.seller_id.to_s])
  end
end
