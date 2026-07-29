require "test_helper"

class ClickEventsControllerTest < ActionDispatch::IntegrationTest
  test "creates click events for new product action types" do
    %w[Make-Offer Share-Ad View-Shop Message-Seller].each do |event_type|
      assert_difference "ClickEvent.count", 1 do
        post "/click_events", params: {
          event_type: event_type,
          ad_id: "test-ad-123",
          device_hash: "abc123",
          user_agent: "Rails Test",
          metadata: { action: "test" }
        }
      end

      assert_response :created
      assert_equal event_type, ClickEvent.last.event_type
    end
  end
end
