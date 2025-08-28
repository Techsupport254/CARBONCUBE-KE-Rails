class Faq < ApplicationRecord
  # Validations
  validates :question, presence: true
  validates :answer, presence: true
end
