# frozen_string_literal: true

module ContentModeration
  class HeuristicRuleEvaluator
    # Category whitelists to prevent false positives (Scunthorpe problem)
    BENIGN_EXCEPTIONS = [
      # Common benign compound terms containing sensitive substrings
      /\bmassage\s+gun\b/i,
      /\bgunmetal(?:\s+grey|\s+gray)?\b/i,
      /\bnail\s+gun\b/i,
      /\bglue\s+gun\b/i,
      /\bgrease\s+gun\b/i,
      /\bheat\s+gun\b/i,
      /\bshot\s+glasses?\b/i,
      /\bchef(?:'s)?\s+knif(?:e|es)\b/i,
      /\bkitchen\s+knif(?:e|es)\b/i,
      /\bcarving\s+knif(?:e|es)\b/i,
      /\bknife\s+sharpener\b/i,
      /\bknife\s+block\b/i,
      /\brefundable\s+(?:security\s+)?deposit\b/i,
      /\bdeposit\s+is\s+refundable\b/i,
      /\bsexy\s+(?:dress|top|lingerie|heels|outfit)\b/i,
      /\bcocktail\s+dress\b/i,
      /\bbikini\s+set\b/i
    ].freeze

    # High-confidence scam patterns (East African / Kenyan marketplace specific)
    SCAM_PATTERNS = [
      {
        pattern: /(?:lipa|send|tuma)\s+(?:deposit|fare|commitment\s+fee).*?(?:kwanza|before|ndio|ili|first)/i,
        category: 'ADVANCE_FEE_SCAM',
        severity: :high,
        risk: 85,
        reason: 'Demands advance deposit or delivery fare before viewing or dispatch'
      },
      {
        pattern: /(?:pay|send|tuma)\s+(?:deposit|delivery\s+fee|commitment\s+fee)\s+(?:first|before\s+dispatch|before\s+viewing|of\s+kes|ya\s+kes)/i,
        category: 'ADVANCE_FEE_SCAM',
        severity: :high,
        risk: 80,
        reason: 'Demands commitment/delivery fee prior to inspection or dispatch'
      },
      {
        pattern: /\b(?:fake\s+notes?|counterfeit\s+money|wash\s+wash|clean\s+black\s+dollars?|pesa\s+za\s+kemikali|ssd\s+solution)\b/i,
        category: 'FINANCIAL_FRAUD',
        severity: :critical,
        risk: 98,
        reason: 'Promoting counterfeit currency or financial wash-wash fraud'
      },
      {
        pattern: /(?:earn|make)\s+(?:\$|kes|sh|ksh)?\s*\d+[kK]?\s+(?:daily|per\s+day|weekly|a\s+day).*?(?:working\s+from\s+home|online|telegram|crypto|invest|doubling)/i,
        category: 'FINANCIAL_FRAUD',
        severity: :high,
        risk: 85,
        reason: 'Get-rich-quick Ponzi / fake work-from-home investment scheme'
      },
      {
        pattern: %r{\b(?:t\.me/(?:joinchat|[a-zA-Z0-9_-]+)|telegram(?:\.me|\.dog)/)\b}i,
        category: 'SUSPICIOUS_REDIRECT',
        severity: :high,
        risk: 80,
        reason: 'External Telegram recruitment or payment redirect link detected'
      }
    ].freeze

    # Prohibited goods patterns
    PROHIBITED_PATTERNS = [
      {
        pattern: /\b(?:unregistered\s+(?:firearm|gun|pistol)|live\s+ammunition|glock\s+19\s+for\s+sale|silencer\s+for\s+sale)\b/i,
        category: 'WEAPONS',
        severity: :critical,
        risk: 95,
        reason: 'Sale of unregistered firearms or ammunition'
      },
      {
        pattern: /\b(?:cytotec|misoprostol|mifepristone)\s*(?:for\s+sale|available|pills)?\b/i,
        category: 'ILLEGAL_PHARMACEUTICALS',
        severity: :critical,
        risk: 95,
        reason: 'Sale of regulated/restricted prescription abortifacients'
      },
      {
        pattern: /\b(?:escort\s+services?|call\s+girls?\s+in|hookups?\s+(?:in|nairobi|mombasa)|erotic\s+massage\s+with\s+happy\s+ending)\b/i,
        category: 'ADULT_SERVICES',
        severity: :critical,
        risk: 95,
        reason: 'Commercial adult escort or sexual services'
      },
      {
        pattern: /\b(?:cocaine|heroin|methamphetamine|crystal\s+meth|bhang\s+cookies\s+for\s+sale)\b/i,
        category: 'ILLICIT_DRUGS',
        severity: :critical,
        risk: 95,
        reason: 'Sale of illicit controlled substances'
      },
      {
        pattern: /\b(?:fake|replica|forged)\s+(?:kenyan\s+)?(?:national\s+id|kcse|certificate|driving\s+licen[sc]e|passport)\b/i,
        category: 'FORGED_DOCUMENTS',
        severity: :critical,
        risk: 95,
        reason: 'Printing or sale of forged/fake official identification documents'
      }
    ].freeze

    # Evaluate text content against heuristic rules
    def self.evaluate(title, description, context = {})
      combined_text = "#{title} #{description}".strip
      return safe_result if combined_text.blank?

      # 1. Mask or exempt verified benign phrases first
      sanitized_text = mask_benign_exceptions(combined_text)

      # 2. Check Prohibited Goods
      PROHIBITED_PATTERNS.each do |rule|
        if sanitized_text.match?(rule[:pattern])
          return {
            risk_score: rule[:risk],
            flagged: true,
            violation_detected: true,
            category: rule[:category],
            severity: rule[:severity],
            reason: rule[:reason],
            rule_matched: rule[:pattern].source
          }
        end
      end

      # 3. Check Scam & Fraud Patterns
      SCAM_PATTERNS.each do |rule|
        if sanitized_text.match?(rule[:pattern])
          return {
            risk_score: rule[:risk],
            flagged: true,
            violation_detected: true,
            category: rule[:category],
            severity: rule[:severity],
            reason: rule[:reason],
            rule_matched: rule[:pattern].source
          }
        end
      end

      # 4. Check for severe Phone Obfuscation in Title (e.g. "0 7 1 2 . . .")
      if title.present? && obfuscated_phone_in_title?(title)
        return {
          risk_score: 45,
          flagged: false, # Soft flag heuristic
          violation_detected: true,
          category: 'OBFUSCATED_CONTACT_IN_TITLE',
          severity: :low,
          reason: 'Phone number obfuscated in listing title to bypass safety measures',
          rule_matched: 'obfuscated_phone_in_title'
        }
      end

      safe_result
    end

    def self.mask_benign_exceptions(text)
      result = text.dup
      BENIGN_EXCEPTIONS.each do |exception_regex|
        result.gsub!(exception_regex, ' [BENIGN_ITEM] ')
      end
      result
    end

    def self.obfuscated_phone_in_title?(title)
      # Checks for spaces/symbols inserted between digits in Kenyan format: e.g. 0 7 1 2 3 4 5 6 7 8
      digits_only = title.scan(/\d/).join
      has_kenyan_length = digits_only.match?(/\A(?:254\d{9}|0(?:7|1)\d{8})\z/)
      has_unusual_spacing = title.match?(/(?:0|254)\s*[.\-\s]\s*[71]\s*[.\-\s]\s*\d\s*[.\-\s]\s*\d/)
      has_kenyan_length && has_unusual_spacing
    end

    def self.safe_result
      {
        risk_score: 0,
        flagged: false,
        violation_detected: false,
        category: 'NONE',
        severity: :none,
        reason: 'No heuristic rule violations detected'
      }
    end
  end
end
