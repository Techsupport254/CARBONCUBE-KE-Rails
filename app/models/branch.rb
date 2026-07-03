class Branch < ApplicationRecord
  belongs_to :seller

  validates :name, presence: true
  validates :location, presence: true
  validates :seller, presence: true

  # Ensure only one main branch per seller
  validate :only_one_main_branch

  before_validation :set_first_branch_as_main

  private

  def only_one_main_branch
    if is_main_branch? && seller.branches.where.not(id: id).where(is_main_branch: true).exists?
      errors.add(:is_main_branch, "can only have one main branch per seller")
    end
  end

  def set_first_branch_as_main
    if seller.branches.count == 0 && !is_main_branch?
      self.is_main_branch = true
    end
  end
end
