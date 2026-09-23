# app/services/google_merchant_text_sanitizer.rb
# Strips promotional/irrelevant text (free delivery claims, contact info,
# price mentions, CTAs) from titles and descriptions before sending them to
# Google Merchant Center. Google disapproves products whose attributes
# contain promotional or irrelevant text.
class GoogleMerchantTextSanitizer
  MIN_TITLE_LENGTH = 10

  # Phrases Google considers promotional text in title/description.
  PROMO_PHRASES = Regexp.union(
    /free\s+(delivery|shipping|gifts?|installation|returns?|warranty|setup|delivery\s+&\s*installation)/i,
    /(same|next)[\s-]?day\s+deliver(y|ies)/i,
    /(express|fast|quick|countrywide|nationwide|doorstep|door[\s-]?to[\s-]?door|home|office|free)\s+deliver(y|ies)/i,
    /deliver(y|ies)?\s+(is\s+|are\s+)?(free|available|done|offered|nationwide|countrywide|within\s+\w+|across\s+\w+|in\s+\w+)/i,
    /we\s+(deliver|ship|offer|install|accept|do\s+deliveries)/i,
    /(cash|pay|payment)\s+(on|upon|after)\s+delivery/i,
    /pay\s+(in\s+)?(small\s+)?installments?/i,
    /lipa\s+(pole\s*pole|mdogo\s*mdogo|later|mos\s*mos)/i,
    /best\s+(price|prices|deal|deals|offer|offers|guarantee)/i,
    /(lowest|cheapest|unbeatable|discounted|special|affordable|pocket[\s-]?friendly)\s+(price|prices|deal|deals|rates?)/i,
    /\b\d{1,2}\s*%\s*(off|discount)/i,
    /(mega|big|hot|flash|clearance|crazy|amazing|special|end\s+of\s+\w+)\s+(sale|deals?|offers?|discounts?|promo)/i,
    /(sale|discount|promo|promotion|offer)s?\s+(alert|now|today|on|valid|available|ongoing|ends?)/i,
    /buy\s+\w+\s+get\s+\w+\s+free/i,
    /(limited|while)\s+(stock|stocks|offer|time|quantity|quantities)/i,
    /while\s+stocks?\s+last/i,
    /(order|buy|shop|hurry|grab\s+yours?|get\s+yours?)\s+(now|today)/i,
    /hurry\s+(up|while)/i,
    /money[\s-]?back\s+guarantee/i,
    /(visit|check)\s+(our|us)\s+(shop|store|showroom|outlet|website|page|insta\w*|fb|facebook)/i,
    /located\s+(at|in|along)\s+\S+/i,
    /\bon\s+sale\b/i,
    /(special|hot|best|great|amazing)\s+(offer|deal)s?\b/i
  ).freeze

  # Contact details and other irrelevant content.
  CONTACT_PATTERNS = Regexp.union(
    %r{(https?://|www\.)\S+}i,
    /\S+@\S+\.\S+/,
    /\+?254[\s.-]?\d{3}[\s.-]?\d{3}[\s.-]?\d{3}\b/,
    /\b0[17]\d{2}[\s.-]?\d{3}[\s.-]?\d{3}\b/,
    /\b(call|whats\s*app|whatsapp|sms|inbox|dm|text|contact|reach)\s+(us|me|now|today|on|at)\b[^,.;|]*?((?=\d)|[,.;|]|$)/i,
    /\bwhatsapp\b/i
  ).freeze

  # Price mentions inside text (price belongs in the price attribute only).
  PRICE_PATTERNS = Regexp.union(
    /\b(?:kshs?|kes|ksh|shs?|ush|tsh)\b\.?\s*:?=?\s*[\d,]+(?:\.\d+)?/i,
    %r{\b[\d,]+\s*/=},
    /\b[\d,]+\s*(bob|shillings|only)\b/i
  ).freeze

  TITLE_SEPARATOR = /\s*[–—|•·]\s*|\s+-\s+/
  TRAILING_PUNCT = /\A[\s\-–—|•·,;:.!?]+|[\s\-–—|•·,;:.!?]+\z/

  def self.clean_title(title)
    return title if title.blank?

    text = strip_contact_info(title.to_s)

    # Titles often append promo segments after separators, e.g.
    # "TV Stand – Free Delivery Nairobi". Drop promo-only segments,
    # keeping the original separators for the segments we keep.
    segments = text.split(TITLE_SEPARATOR)
    separators = text.scan(TITLE_SEPARATOR)
    if segments.length > 1
      text = segments[0].to_s
      segments[1..].each_with_index do |seg, idx|
        next if seg.match?(PROMO_PHRASES)

        text += separators[idx].to_s + seg
      end
    end

    text = text.gsub(PROMO_PHRASES, ' ')
    text = text.gsub(TRAILING_PUNCT, '')
    text = text.gsub(/\s{2,}/, ' ').strip

    # If cleaning gutted the title, fall back to contact-stripped original
    # rather than emitting a too-short title.
    text.length >= MIN_TITLE_LENGTH ? text : strip_contact_info(title.to_s).gsub(TRAILING_PUNCT, '').gsub(/\s{2,}/, ' ').strip
  end

  def self.clean_description(description)
    return description if description.blank?

    text = strip_contact_info(description.to_s)
    text = text.gsub(PROMO_PHRASES, ' ')
    text = text.gsub(PRICE_PATTERNS, ' ')
    text = text.gsub(/[ \t]{2,}/, ' ')
    text.gsub(/\n{3,}/, "\n\n").strip
  end

  def self.strip_contact_info(text)
    cleaned = text.gsub(CONTACT_PATTERNS, ' ')
    # Remaining long digit runs (9+ digits) are almost certainly phone numbers
    cleaned = cleaned.gsub(/\+?\d[\d\s().-]{7,}\d/) do |match|
      match.scan(/\d/).length >= 9 ? ' ' : match
    end
    # CTA words left dangling at the end after their number was removed
    cleaned.gsub(/\b(?:call|whatsapp|whats\s*app|sms|contact|inbox|dm|text)\s*(?:us|me|now|today|here)?\s*(?=[\s\-–—|•·,;:.!?]*\z)/i, '')
  end
end
