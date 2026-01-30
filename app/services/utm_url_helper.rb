# frozen_string_literal: true

# Appends UTM parameters to a URL for tracking (WhatsApp, email, etc.).
# Use for any link we send to users so analytics can attribute traffic correctly.
#
# Usage:
#   UtmUrlHelper.append_utm(url, source: 'whatsapp', medium: 'notification', campaign: 'message', content: conversation_id)
module UtmUrlHelper
  class << self
    # @param url [String] base URL (e.g. https://carboncube-ke.com/ads/iphone-16?id=123)
    # @param source [String] utm_source (e.g. whatsapp, email)
    # @param medium [String] utm_medium (e.g. notification, welcome, contact)
    # @param campaign [String] utm_campaign (e.g. message, signup, ad_inquiry)
    # @param content [String, nil] utm_content optional (e.g. ad id, conversation id)
    # @param term [String, nil] utm_term optional (e.g. product title)
    # @return [String] URL with UTM query params appended
    def append_utm(url, source:, medium:, campaign:, content: nil, term: nil)
      return url if url.blank?

      begin
        uri = URI.parse(url)
        params = (uri.query ? URI.decode_www_form(uri.query).to_h : {}).stringify_keys
        params['utm_source'] = source.to_s.presence
        params['utm_medium'] = medium.to_s.presence
        params['utm_campaign'] = campaign.to_s.presence
        params['utm_content'] = content.to_s.presence if content.present?
        params['utm_term'] = term.to_s.presence if term.present?
        params.compact!
        uri.query = params.empty? ? nil : URI.encode_www_form(params)
        uri.to_s
      rescue URI::InvalidURIError, ArgumentError
        url
      end
    end
  end
end
