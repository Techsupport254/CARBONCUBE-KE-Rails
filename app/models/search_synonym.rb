# frozen_string_literal: true

# A single search synonym pair for the buyer search pipeline.
#
# Pairs are stored once and expanded bidirectionally by SearchSynonymExpander,
# so (term, synonym) is symmetric: a query containing either side yields the other.
#
class SearchSynonym < ApplicationRecord
  before_validation :normalize_fields

  validates :term, :synonym, presence: true
  validates :synonym, uniqueness: { scope: :term }

  scope :for_term, ->(t) { where(term: t.to_s.downcase.strip) }

  private

  def normalize_fields
    self.term = term.to_s.downcase.strip.presence
    self.synonym = synonym.to_s.downcase.strip.presence
  end
end
