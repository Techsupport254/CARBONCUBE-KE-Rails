require "test_helper"

class ClickEventTest < ActiveSupport::TestCase
  test "valid for all new product action event types" do
    %w[
      Ad-Click
      Reveal-Seller-Details
      Add-to-Cart
      Add-to-Wish-List
      Callback-Request
      Make-Offer
      Share-Ad
      View-Shop
      Message-Seller
    ].each do |event_type|
      click_event = ClickEvent.new(event_type: event_type, metadata: { source: "test" })
      assert click_event.valid?, "Expected #{event_type} to be valid: #{click_event.errors.full_messages.join(", ")}"
      assert click_event.save, "Expected #{event_type} to save"
    end
  end

  test "invalid for unknown event types" do
    click_event = ClickEvent.new(event_type: "Invalid-Event", metadata: { source: "test" })
    assert_not click_event.valid?
    assert_includes click_event.errors[:event_type], "is not included in the list"
  end
end
