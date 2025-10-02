class IssueAttachment < ApplicationRecord
  # Associations
  belongs_to :issue
  belongs_to :uploaded_by, polymorphic: true
  
  # Validations
  validates :file_name, presence: true
  validates :file_size, presence: true, numericality: { greater_than: 0 }
  validates :file_type, presence: true
  validates :uploaded_by_type, presence: true
  validates :uploaded_by_id, presence: true
  
  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_type, ->(type) { where(file_type: type) }
  scope :images, -> { where(file_type: ['image/jpeg', 'image/png', 'image/gif', 'image/webp']) }
  scope :documents, -> { where(file_type: ['application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document']) }
  
  # Methods
  def file_size_mb
    (file_size / 1024.0 / 1024.0).round(2)
  end
  
  def file_size_kb
    (file_size / 1024.0).round(2)
  end
  
  def formatted_file_size
    if file_size_mb >= 1
      "#{file_size_mb} MB"
    else
      "#{file_size_kb} KB"
    end
  end
  
  def is_image?
    file_type.start_with?('image/')
  end
  
  def is_document?
    file_type.start_with?('application/')
  end
  
  def uploaded_by_name
    case uploaded_by_type
    when 'Admin'
      uploaded_by.fullname || uploaded_by.email
    when 'User'
      uploaded_by.fullname || uploaded_by.email
    else
      'Anonymous'
    end
  end
  
  def time_ago
    time_ago_in_words(created_at)
  end
end
