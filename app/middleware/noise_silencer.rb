# frozen_string_literal: true

# Lowers the Rails log level to :warn for a configured set of high-volume,
# routine endpoints. This keeps error/warning logs visible while suppressing
# the verbose INFO output (Started/Processing/Parameters/Completed) that
# currently dominates production logs.
class NoiseSilencer
  # Paths matched exactly (QUERY_STRING is not part of PATH_INFO)
  NOISY_EXACT_PATHS = %w[
    /buyer/categories
    /buyer/offers
    /buyer/ads
    /buyer/ads/recommendations
    /counties
    /device_fingerprints/store
    /device_fingerprints/recover
    /internal_user_exclusions/check_ip
    /source-tracking/track
    /visitor/track
  ].freeze

  # Paths that start with these prefixes are also quieted
  NOISY_PREFIX_PATHS = %w[
    /internal_user_exclusions/check/
  ].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    path = env["PATH_INFO"].to_s

    if noisy?(path)
      # ActiveSupport::Logger#silence uses a thread-local level, so this is
      # safe for concurrent requests.
      Rails.logger.silence(Logger::WARN) { @app.call(env) }
    else
      @app.call(env)
    end
  end

  private

  def noisy?(path)
    NOISY_EXACT_PATHS.include?(path) ||
      NOISY_PREFIX_PATHS.any? { |prefix| path.start_with?(prefix) }
  end
end
