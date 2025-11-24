# Fix SMTP SSL certificate verification issues
# This initializer ensures emails can be sent even with SSL certificate issues

if Rails.env.development?
  require 'mail'
  require 'openssl'
  
  # Configure Mail gem to handle SSL certificate errors
  Mail.defaults do
    delivery_method :smtp, {
      openssl_verify_mode: OpenSSL::SSL::VERIFY_NONE
    }
  end
  
  # Also patch ActionMailer SMTP settings after initialization
  Rails.application.config.after_initialize do
    if ActionMailer::Base.delivery_method == :smtp
      smtp_settings = ActionMailer::Base.smtp_settings || {}
      smtp_settings[:openssl_verify_mode] = OpenSSL::SSL::VERIFY_NONE
      ActionMailer::Base.smtp_settings = smtp_settings
      Rails.logger.info "✅ SMTP SSL verification disabled for development"
    end
  end
end

