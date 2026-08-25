class SalesHoliday < ApplicationRecord
  validates :name, presence: true
  validates :date, presence: true, uniqueness: { scope: :name }

  # Check if a given date falls on any holiday (including recurring ones).
  # Recurring holidays match by month + day regardless of year.
  def self.holiday_on?(date)
    for_date(date).present?
  end

  # Return the holiday record for a given date, if any.
  # Checks exact date first, then recurring holidays by month/day.
  def self.for_date(date)
    date = Date.parse(date.to_s) unless date.is_a?(Date)
    find_by(date: date) || where(recurring: true).find do |holiday|
      holiday.date.month == date.month && holiday.date.day == date.day
    end
  end

  # Days sales users are NOT expected to share field locations:
  # - Configured holidays
  # - Wednesdays (all-staff meetings)
  # - Saturday and Sunday (weekends)
  def self.non_working_day?(date)
    date = Date.parse(date.to_s) unless date.is_a?(Date)
    return true if date.saturday? || date.sunday? || date.wednesday?

    holiday_on?(date)
  end

  # Human-readable reason the day is exempt, if any.
  def self.exemption_name(date)
    date = Date.parse(date.to_s) unless date.is_a?(Date)
    return 'Weekend' if date.saturday? || date.sunday?
    return 'Wednesday meeting' if date.wednesday?

    for_date(date)&.name
  end
end
