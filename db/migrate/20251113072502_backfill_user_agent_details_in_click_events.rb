class BackfillUserAgentDetailsInClickEvents < ActiveRecord::Migration[7.0]
  def up
    # Find all click events that have user_agent but no user_agent_details
    base_query = ClickEvent.where("metadata->>'user_agent' IS NOT NULL")
                            .where("metadata->'user_agent_details' IS NULL OR metadata->'user_agent_details'->>'browser' IS NULL")
    
    total_count = base_query.count

    Rails.logger.info "BackfillUserAgentDetailsInClickEvents: Starting backfill for #{total_count} records"

    processed = 0
    errors = 0
    batch_size = 1000

    # Process in batches to avoid memory issues
    base_query.find_each(batch_size: batch_size) do |click_event|
      begin
        metadata = click_event.metadata || {}
        user_agent_string = metadata['user_agent'] || metadata[:user_agent]

        next unless user_agent_string.present?

        # Parse user agent using the same logic as BackfillUserAgentDetailsJob
        user_agent_details = parse_user_agent(user_agent_string)

        # Update metadata with parsed details
        metadata['user_agent_details'] = user_agent_details
        metadata[:user_agent_details] = user_agent_details

        # Update the record using update_column to avoid validations and callbacks
        click_event.update_column(:metadata, metadata)

        processed += 1

        # Log progress every 1000 records
        if processed % 1000 == 0
          Rails.logger.info "BackfillUserAgentDetailsInClickEvents: Processed #{processed}/#{total_count} records"
        end
      rescue StandardError => e
        errors += 1
        Rails.logger.error "BackfillUserAgentDetailsInClickEvents: Error processing click_event #{click_event.id}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end

    Rails.logger.info "BackfillUserAgentDetailsInClickEvents: Completed! Processed: #{processed}, Errors: #{errors}, Total: #{total_count}"
  end

  def down
    # This migration is not reversible - we don't want to remove user_agent_details
    # as it improves query performance
    Rails.logger.info "BackfillUserAgentDetailsInClickEvents: Migration is not reversible"
  end

  private

  def parse_user_agent(user_agent_string)
    return {} unless user_agent_string.present?

    begin
      require 'user_agent_parser'
      parser = UserAgentParser.parse(user_agent_string)

      # Extract browser information
      browser_name = parser.family
      browser_version = parser.version&.to_s

      # Extract OS information
      os_family = parser.os&.family
      os_version = parser.os&.version&.to_s

      # Detect device type
      user_agent_lower = user_agent_string.downcase
      device_type = detect_device_type(user_agent_lower)

      {
        browser: browser_name || 'Unknown',
        browser_version: browser_version,
        os: os_family || 'Unknown',
        os_version: os_version,
        device_type: device_type,
        is_mobile: mobile_device?(user_agent_lower),
        is_tablet: tablet_device?(user_agent_lower),
        is_desktop: desktop_device?(user_agent_lower)
      }
    rescue LoadError, StandardError => e
      # Fallback to basic detection if gem is not available or fails
      Rails.logger.warn "User agent parser failed for '#{user_agent_string}': #{e.message}"
      user_agent_lower = user_agent_string.downcase

      {
        browser: detect_browser_fallback(user_agent_lower),
        browser_version: nil,
        os: detect_os_fallback(user_agent_lower),
        os_version: nil,
        device_type: detect_device_type(user_agent_lower),
        is_mobile: mobile_device?(user_agent_lower),
        is_tablet: tablet_device?(user_agent_lower),
        is_desktop: desktop_device?(user_agent_lower)
      }
    end
  end

  def detect_device_type(user_agent_lower)
    return 'mobile' if mobile_device?(user_agent_lower)
    return 'tablet' if tablet_device?(user_agent_lower)
    'desktop'
  end

  def mobile_device?(user_agent_lower)
    user_agent_lower.match?(/mobile|android|iphone|ipod|blackberry|opera mini|iemobile|wpdesktop/i)
  end

  def tablet_device?(user_agent_lower)
    user_agent_lower.match?(/tablet|ipad|playbook|silk/i) && !user_agent_lower.match?(/mobile/i)
  end

  def desktop_device?(user_agent_lower)
    !mobile_device?(user_agent_lower) && !tablet_device?(user_agent_lower)
  end

  def detect_browser_fallback(user_agent_lower)
    if user_agent_lower.include?('chrome') && !user_agent_lower.include?('edg')
      'Chrome'
    elsif user_agent_lower.include?('edg')
      'Edge'
    elsif user_agent_lower.include?('firefox')
      'Firefox'
    elsif user_agent_lower.include?('safari') && !user_agent_lower.include?('chrome')
      'Safari'
    elsif user_agent_lower.include?('opera') || user_agent_lower.include?('opr')
      'Opera'
    elsif user_agent_lower.include?('msie') || user_agent_lower.include?('trident')
      'Internet Explorer'
    else
      'Unknown'
    end
  end

  def detect_os_fallback(user_agent_lower)
    if user_agent_lower.include?('windows')
      'Windows'
    elsif user_agent_lower.include?('mac os') || user_agent_lower.include?('macintosh')
      'macOS'
    elsif user_agent_lower.include?('linux') && !user_agent_lower.include?('android')
      'Linux'
    elsif user_agent_lower.include?('android')
      'Android'
    elsif user_agent_lower.include?('iphone') || user_agent_lower.include?('ipad') || user_agent_lower.include?('ipod')
      'iOS'
    else
      'Unknown'
    end
  end
end
