class Faq < ApplicationRecord
  CATEGORIES = %w[account buying payments selling technical general].freeze

  # Validations
  validates :question, presence: true
  validates :answer, presence: true
  validates :category, inclusion: { in: CATEGORIES }

  scope :ordered, -> { order(position: :asc, helpful_count: :desc, created_at: :asc) }
end
