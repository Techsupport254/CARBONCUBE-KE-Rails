# config/initializers/google_merchant.rb
# Google Merchant API Configuration

# Google Merchant Center Configuration
Rails.application.configure do
  # Google Merchant Center Account ID
  # Set this in your environment variables
  config.google_merchant_account_id = ENV['GOOGLE_MERCHANT_ACCOUNT_ID']
  
  # Google Cloud Project ID
  config.google_cloud_project_id = ENV['GOOGLE_CLOUD_PROJECT_ID']
  
  # Service Account Key File Path
  # This should point to your Google Cloud service account JSON key file
  config.google_service_account_key_path = ENV['GOOGLE_SERVICE_ACCOUNT_KEY_PATH']
  
  # API Base URL
  config.google_merchant_api_base_url = 'https://merchantapi.googleapis.com/products/v1'
  
  # Rate limiting settings
  config.google_merchant_rate_limit = {
    requests_per_minute: 100,
    requests_per_hour: 1000
  }
  
  # Sync settings
  config.google_merchant_sync = {
    enabled: ENV['GOOGLE_MERCHANT_SYNC_ENABLED'] == 'true',
    batch_size: 50,
    delay_between_requests: 0.1, # seconds
    retry_attempts: 3,
    retry_delay: 5 # seconds
  }
end

# Validate configuration on startup
Rails.application.config.after_initialize do
  if Rails.application.config.google_merchant_sync[:enabled]
    required_env_vars = %w[
      GOOGLE_MERCHANT_ACCOUNT_ID
      GOOGLE_CLOUD_PROJECT_ID
      GOOGLE_SERVICE_ACCOUNT_KEY_PATH
    ]
    
    missing_vars = required_env_vars.select { |var| ENV[var].blank? }
    
    if missing_vars.any?
      Rails.logger.warn "Google Merchant API configuration incomplete. Missing: #{missing_vars.join(', ')}"
      Rails.logger.warn "Google Merchant sync is disabled until configuration is complete."
    else
      Rails.logger.info "Google Merchant API configuration loaded successfully"
    end
  end
end
