# frozen_string_literal: true

WebAuthn.configure do |config|
  config.allowed_origins = [ENV.fetch("WEBAUTHN_ORIGIN", "https://carboncube-ke.com")]
  config.rp_id = ENV.fetch("WEBAUTHN_RP_ID", "carboncube-ke.com")
  config.rp_name = "Carbon Cube Kenya"
end
