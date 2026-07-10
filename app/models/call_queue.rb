class CallQueue < ApplicationRecord
  belongs_to :seller
  belongs_to :resolved_by, class_name: 'SalesUser', optional: true, foreign_key: 'resolved_by_id'

  # Queue types
  UNREAD_MESSAGES = 'unread_messages'
  NO_ADS_UPLOADED = 'no_ads_uploaded'
  INACTIVE_SELLER = 'inactive_seller'
  NEW_SELLER_ONBOARDING = 'new_seller_onboarding'
  DOCUMENT_EXPIRY = 'document_expiry'
  PROACTIVE_OUTREACH = 'proactive_outreach'

  # Queue types mapping for API
  QUEUE_TYPES = {
    UNREAD_MESSAGES => 'Unread Messages',
    NO_ADS_UPLOADED => 'No Ads Uploaded',
    INACTIVE_SELLER => 'Inactive Seller',
    NEW_SELLER_ONBOARDING => 'New Seller Onboarding',
    DOCUMENT_EXPIRY => 'Document Expiry',
    PROACTIVE_OUTREACH => 'Proactive Outreach'
  }.freeze

  # Status
  STATUS_PENDING = 'pending'
  STATUS_IN_PROGRESS = 'in_progress'
  STATUS_RESOLVED = 'resolved'

  # Priority levels (higher = more urgent)
  PRIORITY_CRITICAL = 3
  PRIORITY_HIGH = 2
  PRIORITY_MEDIUM = 1
  PRIORITY_LOW = 0

  # Scopes
  scope :pending, -> { where(status: STATUS_PENDING) }
  scope :in_progress, -> { where(status: STATUS_IN_PROGRESS) }
  scope :resolved, -> { where(status: STATUS_RESOLVED) }
  scope :by_priority, -> { order(priority: :desc, created_at: :asc) }
  scope :by_type, ->(type) { where("reasons::jsonb @> ?", "[\"#{type}\"]") }
  scope :with_reason, ->(type) { where("reasons::jsonb @> ?", "[\"#{type}\"]") }

  # Serialize reasons array
  serialize :reasons, coder: JSON

  # Validations
  validates :reasons, presence: true
  validates :status, presence: true, inclusion: {
    in: [STATUS_PENDING, STATUS_IN_PROGRESS, STATUS_RESOLVED]
  }
  validates :priority, numericality: { only_integer: true, in: 0..3 }
  
  # Ensure unique seller per queue (only for pending entries)
  validates :seller_id, uniqueness: { scope: :status }, if: -> { status == STATUS_PENDING }

  # Mark as resolved
  def resolve!(user_id)
    update!(status: STATUS_RESOLVED, resolved_at: Time.current, resolved_by_id: user_id)
  end

  # Mark as in progress
  def start!
    update!(status: STATUS_IN_PROGRESS)
  end

  # Check if queue entry is stale (older than 7 days and still pending)
  def stale?
    status == STATUS_PENDING && created_at < 7.days.ago
  end

  # Convert to API response format
  def to_api_response
    {
      id: id,
      seller_id: seller_id,
      seller_name: seller.fullname,
      seller_email: seller.email,
      seller_phone: seller.phone_number,
      seller_enterprise: seller.enterprise_name,
      seller_profile_picture: seller.profile_picture,
      reasons: reasons,
      reasons_display: reasons.map { |r| QUEUE_TYPES[r] || r.humanize },
      priority: priority,
      priority_display: priority_display,
      status: status,
      metadata: metadata,
      created_at: created_at,
      days_in_queue: ((Time.current - created_at).to_i / 86400).to_i
    }
  end

  private

  def priority_display
    case priority
    when PRIORITY_CRITICAL then 'Critical'
    when PRIORITY_HIGH then 'High'
    when PRIORITY_MEDIUM then 'Medium'
    when PRIORITY_LOW then 'Low'
    else 'Unknown'
    end
  end
end
