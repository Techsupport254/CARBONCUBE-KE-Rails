# frozen_string_literal: true

# Popularity-based ranking boost for search results.
#
# Converts per-ad engagement signals (click_events rows) from the last 30 days
# into a 0..10 boost score. Event types are weighted by intent strength — a
# Callback-Request or Message-Seller is a much stronger buy signal than a
# passive Ad-Click, and View-Shop is about the shop rather than the ad so it
# only counts for half.
#
# All signals are aggregated in a single GROUP BY ad_id query over the batch of
# ad ids (no N+1), then log-normalized so the most-engaged ad in the batch
# scores ~10 and the rest scale proportionally:
#
#   boost = 10 * log1p(weighted_count) / log1p(max_weighted_count_in_batch)
#
# Ads with no recent engagement are simply absent from the returned map —
# callers should treat a missing key as a boost of 0.
#
class SearchPopularityBoost
  LOOKBACK_PERIOD = 30.days
  MAX_BOOST = 10.0

  # Intent-weighted value per click_events.event_type. Only real prod values
  # that carry ad-level engagement signal are listed; unknown types are ignored.
  EVENT_WEIGHTS = {
    "Ad-Click" => 1.0,
    "Share-Ad" => 2.0,
    "Reveal-Seller-Details" => 3.0,
    "Add-to-Wish-List" => 4.0,
    "Callback-Request" => 5.0,
    "Message-Seller" => 5.0,
    "Make-Offer" => 5.0,
    "View-Shop" => 0.5
  }.freeze

  class << self
    # @param ad_ids [Array<Integer>] ad ids in the current search batch
    # @return [Hash{Integer => Float}] ad_id => boost in 0..10; missing keys mean 0
    def score_map(ad_ids)
      ids = Array(ad_ids).map(&:to_i).uniq
      return {} if ids.empty?

      weighted = weighted_counts(ids)
      return {} if weighted.empty?

      normalize(weighted)
    rescue ActiveRecord::StatementInvalid => e
      # click_events table may be missing (fresh env, pending migration) —
      # degrade gracefully so callers still get a usable (empty) boost map.
      Rails.logger.warn("SearchPopularityBoost skipped: #{e.message}")
      {}
    end

    private

    # One aggregate query: SUM(event weight) per ad_id over the lookback window.
    # Uses the index on click_events(ad_id, created_at).
    def weighted_counts(ids)
      ClickEvent
        .where(ad_id: ids)
        .where(event_type: EVENT_WEIGHTS.keys)
        .where(created_at: LOOKBACK_PERIOD.ago..)
        .group(:ad_id)
        .sum(weight_expression)
    end

    # CASE expression mapping event_type to its weight inside SUM().
    # Values come from the EVENT_WEIGHTS constant — no user input is interpolated.
    def weight_expression
      branches = EVENT_WEIGHTS.map { |type, weight| "WHEN '#{type}' THEN #{weight}" }.join(" ")
      Arel.sql("CASE event_type #{branches} ELSE 0 END")
    end

    def normalize(weighted)
      max = weighted.values.map(&:to_f).max.to_f
      return {} if max <= 0

      denominator = Math.log1p(max)
      weighted.each_with_object({}) do |(ad_id, count), result|
        count = count.to_f
        next if count <= 0

        result[ad_id.to_i] = (MAX_BOOST * Math.log1p(count) / denominator).round(2)
      end
    end
  end
end
