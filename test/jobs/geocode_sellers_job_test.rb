require "test_helper"

class GeocodeSellersJobTest < ActiveSupport::TestCase
  def setup
    @job = GeocodeSellersJob.new
    @seller = Seller.new(
      email: "geocode-test-#{SecureRandom.hex(4)}@example.com",
      fullname: "Pantech Test Seller",
      enterprise_name: "PANTECH KENYA LIMITED",
      phone_number: "0712345678",
      location: "Lunga Lunga Road, Industrial Area, P.O. Box 12345-00100",
      city: "Nairobi"
    )
  end

  test "sanitizes location by stripping PO Box and phone numbers" do
    cleaned = @job.send(:sanitize_location, "Lunga Lunga Road, Industrial Area, P.O. Box 12345-00100, 0712345678")
    assert_equal "Lunga Lunga Road, Industrial Area", cleaned
  end

  test "geocode_location builds clean query candidates" do
    queries_tested = []
    fake_search = ->(query, county, sync) do
      queries_tested << query
      nil
    end

    @job.stub(:nominatim_search, fake_search) do
      @job.send(:geocode_location, @seller, sync: true)
    end

    assert queries_tested.any? { |q| q.include?("Lunga Lunga Road, Industrial Area") }, "Expected queries to include cleaned location"
    assert queries_tested.any? { |q| q.include?("Kenya") }, "Expected queries to include Kenya"
  end
end

