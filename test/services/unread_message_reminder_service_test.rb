# frozen_string_literal: true

require "test_helper"

class UnreadMessageReminderServiceTest < ActiveSupport::TestCase
  test "constants and intervals are configured correctly" do
    assert_equal "ping_seller_message_v1", UnreadMessageReminderService::TEMPLATE_NAME
    assert_equal 3, UnreadMessageReminderService::MAX_REMINDERS
    assert_equal 30.minutes, UnreadMessageReminderService::INTERVALS[1]
    assert_equal 3.hours, UnreadMessageReminderService::INTERVALS[2]
    assert_equal 24.hours, UnreadMessageReminderService::INTERVALS[3]
  end

  test "in_quiet_hours detects hours between 10 PM and 7 AM EAT" do
    nairobi_tz = ActiveSupport::TimeZone["Africa/Nairobi"]

    # 11:30 PM EAT should be in quiet hours
    night_time = nairobi_tz.parse("2026-09-28 23:30:00")
    assert UnreadMessageReminderService.in_quiet_hours?(night_time)

    # 3:00 AM EAT should be in quiet hours
    early_morning = nairobi_tz.parse("2026-09-29 03:00:00")
    assert UnreadMessageReminderService.in_quiet_hours?(early_morning)

    # 6:59 AM EAT should be in quiet hours
    before_seven = nairobi_tz.parse("2026-09-29 06:59:00")
    assert UnreadMessageReminderService.in_quiet_hours?(before_seven)

    # 10:00 AM EAT should NOT be in quiet hours
    day_time = nairobi_tz.parse("2026-09-28 10:00:00")
    assert_not UnreadMessageReminderService.in_quiet_hours?(day_time)

    # 4:00 PM EAT should NOT be in quiet hours
    afternoon = nairobi_tz.parse("2026-09-28 16:00:00")
    assert_not UnreadMessageReminderService.in_quiet_hours?(afternoon)
  end

  test "next_quiet_hours_end returns 8:00 AM EAT" do
    nairobi_tz = ActiveSupport::TimeZone["Africa/Nairobi"]

    # At 11:00 PM on Sept 28, next quiet hours end should be 8:00 AM on Sept 29
    night_time = nairobi_tz.parse("2026-09-28 23:00:00")
    next_end = UnreadMessageReminderService.next_quiet_hours_end(night_time).in_time_zone("Africa/Nairobi")
    assert_equal 8, next_end.hour
    assert_equal 0, next_end.min
    assert_equal 29, next_end.day

    # At 4:00 AM on Sept 29, next quiet hours end should be 8:00 AM on Sept 29
    early_morning = nairobi_tz.parse("2026-09-29 04:00:00")
    next_end_morning = UnreadMessageReminderService.next_quiet_hours_end(early_morning).in_time_zone("Africa/Nairobi")
    assert_equal 8, next_end_morning.hour
    assert_equal 0, next_end_morning.min
    assert_equal 29, next_end_morning.day
  end
end
