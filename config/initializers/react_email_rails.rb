Rails.application.configure do
  config.react_email_rails = ActiveSupport::OrderedOptions.new unless config.respond_to?(:react_email_rails)

  config.react_email_rails.tap do |config|
    # Render timeout in seconds (default: 15)
    config.render_timeout = 30

    # Transform prop keys to camelCase (default: :lower_camel)
    config.transform_props = :lower_camel

    # Deep merge shared props (default: false)
    config.deep_merge_shared_props = false
  end
end
