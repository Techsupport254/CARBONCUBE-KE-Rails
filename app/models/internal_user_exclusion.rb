class InternalUserExclusion < ApplicationRecord
  validates :identifier_type, presence: true, inclusion: { in: %w[device_hash user_agent ip_range email_domain] }
  validates :identifier_value, presence: true
  validates :reason, presence: true
  validates :active, inclusion: { in: [true, false] }
  
  # Additional fields for removal requests
  validates :requester_name, presence: true, if: :removal_request?
  validates :device_description, presence: true, if: :removal_request?
  validates :user_agent, presence: true, if: :removal_request?
  validates :status, inclusion: { in: %w[pending approved rejected] }, if: :removal_request?
  
  # Scope for active exclusions
  scope :active, -> { where(active: true) }
  
  # Scope by identifier type
  scope :by_type, ->(type) { where(identifier_type: type) }
  
  # Scopes for removal requests
  scope :removal_requests, -> { where.not(requester_name: nil) }
  scope :pending_requests, -> { removal_requests.where(status: 'pending') }
  scope :approved_requests, -> { removal_requests.where(status: 'approved') }
  scope :rejected_requests, -> { removal_requests.where(status: 'rejected') }
  
  # Check if this is a removal request
  def removal_request?
    requester_name.present?
  end
  
  # Check if a device hash is excluded
  def self.device_hash_excluded?(device_hash)
    return false if device_hash.blank?
    
    # First, check for exact match or prefix match (for modified hashes like q4bjv01, q4bjv02)
    if active.by_type('device_hash')
         .where('identifier_value = ? OR identifier_value LIKE ?', device_hash, "#{device_hash}%")
         .exists?
      return true
    end
    
    # Second, check if this device hash is a modified version of an approved hash
    # Remove trailing numbers to get the base hash (e.g., q4bjv01 -> q4bjv0)
    base_hash = device_hash.gsub(/\d+$/, '')
    if base_hash != device_hash
      # Check if the base hash is approved
      if active.by_type('device_hash')
           .where('identifier_value = ? OR identifier_value LIKE ?', base_hash, "#{base_hash}%")
           .exists?
        return true
      end
    end
    
    false
  end
  
  # Check if a user agent is excluded
  def self.user_agent_excluded?(user_agent)
    return false if user_agent.blank?
    
    active.by_type('user_agent').each do |exclusion|
      # Use regex pattern matching for user agent exclusions
      pattern = exclusion.identifier_value
      return true if user_agent.match?(Regexp.new(pattern, Regexp::IGNORECASE))
    end
    
    false
  end
  
  # Check if an IP address is in excluded range
  def self.ip_excluded?(ip_address)
    return false if ip_address.blank?
    
    active.by_type('ip_range').each do |exclusion|
      return true if ip_in_range?(ip_address, exclusion.identifier_value)
    end
    
    false
  end
  
  # Check if an email domain or exact email is excluded
  def self.email_domain_excluded?(email)
    return false if email.blank?
    
    email_lower = email.downcase
    
    # First check for exact email match
    if active.by_type('email_domain')
         .where('LOWER(identifier_value) = ?', email_lower)
         .exists?
      return true
    end
    
    # Then check for domain match
    domain = email.split('@').last&.downcase
    return false if domain.blank?
    
    active.by_type('email_domain')
         .where('LOWER(identifier_value) = ? OR identifier_value LIKE ?', domain, "%#{domain}%")
         .exists?
  end
  
  # Check if any identifier matches exclusion criteria
  def self.should_exclude?(device_hash: nil, user_agent: nil, ip_address: nil, email: nil)
    return true if device_hash_excluded?(device_hash)
    return true if user_agent_excluded?(user_agent)
    return true if ip_excluded?(ip_address)
    return true if email_domain_excluded?(email)
    
    false
  end
  
  # Removal request methods
  
  # Check if a device hash has a pending request
  def self.has_pending_request?(device_hash)
    pending_requests.where(identifier_value: device_hash).exists?
  end
  
  # Check if a device hash has an approved request
  def self.has_approved_request?(device_hash)
    approved_requests.where(identifier_value: device_hash).exists?
  end
  
  # Create a new removal request
  def self.create_removal_request(attributes)
    create!(
      identifier_type: 'device_hash',
      identifier_value: attributes[:device_hash],
      reason: "Removal request: #{attributes[:requester_name]} - #{attributes[:device_description]}",
      active: false, # Initially inactive until approved
      requester_name: attributes[:requester_name],
      device_description: attributes[:device_description],
      user_agent: attributes[:user_agent],
      status: 'pending',
      additional_info: attributes[:additional_info] # Store IP and other metadata
    )
  end
  
  # Approve a removal request
  def approve!
    return false unless removal_request? && status == 'pending'
    
    ActiveRecord::Base.transaction do
      # Activate the exclusion
      update!(
        active: true,
        status: 'approved',
        approved_at: Time.current
      )
      
      # Create additional IP-based exclusion for enhanced persistence
      # This ensures the device remains excluded even if the device hash changes
      create_ip_based_exclusion_if_needed
    end
  rescue => e
    errors.add(:base, "Failed to approve request: #{e.message}")
    false
  end
  
  # Reject a removal request
  def reject!(rejection_reason = nil)
    return false unless removal_request? && status == 'pending'
    
    update!(
      status: 'rejected',
      rejection_reason: rejection_reason,
      rejected_at: Time.current
    )
  end
  
  private
  
  # Create IP-based exclusion for enhanced persistence when approving removal requests
  def create_ip_based_exclusion_if_needed
    return unless additional_info.present?
    
    # Extract IP information from additional_info
    ip_info = additional_info['ip_info'] || additional_info[:ip_info]
    return unless ip_info.present?
    
    # Get all IP addresses that were captured during the request
    all_ips = ip_info['all_ips'] || ip_info[:all_ips] || []
    return if all_ips.empty?
    
    # Create IP-based exclusions for each captured IP
    all_ips.each do |ip|
      next if ip.blank?
      
      # Create IP-based exclusion if it doesn't already exist
      existing_ip_exclusion = InternalUserExclusion.find_by(
        identifier_type: 'ip_range',
        identifier_value: ip
      )
      
      unless existing_ip_exclusion
        InternalUserExclusion.create!(
          identifier_type: 'ip_range',
          identifier_value: ip,
          reason: "IP-based exclusion created from approved removal request (#{identifier_value})",
          active: true,
          status: 'approved',
          approved_at: Time.current,
          additional_info: {
            created_from_removal_request: true,
            original_device_hash: identifier_value,
            requester_name: requester_name
          }
        )
      end
    end
  rescue => e
    # Log error but don't fail the approval process
    Rails.logger.error "Failed to create IP-based exclusions: #{e.message}"
  end
  
  # Check if IP is in range (supports CIDR notation and simple ranges)
  def self.ip_in_range?(ip, range)
    return false if ip.blank? || range.blank?
    
    # Handle CIDR notation (e.g., "192.168.1.0/24")
    if range.include?('/')
      require 'ipaddr'
      begin
        ip_range = IPAddr.new(range)
        ip_addr = IPAddr.new(ip)
        return ip_range.include?(ip_addr)
      rescue IPAddr::InvalidAddressError
        return false
      end
    end
    
    # Handle simple IP ranges (e.g., "192.168.1.1-192.168.1.255")
    if range.include?('-')
      start_ip, end_ip = range.split('-')
      return ip_between?(ip, start_ip.strip, end_ip.strip)
    end
    
    # Exact match
    ip == range
  end
  
  # Check if IP is between two IPs
  def self.ip_between?(ip, start_ip, end_ip)
    require 'ipaddr'
    begin
      ip_addr = IPAddr.new(ip)
      start_addr = IPAddr.new(start_ip)
      end_addr = IPAddr.new(end_ip)
      
      ip_addr >= start_addr && ip_addr <= end_addr
    rescue IPAddr::InvalidAddressError
      false
    end
  end
end
