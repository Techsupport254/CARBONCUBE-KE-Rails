# frozen_string_literal: true

# Synonym expansion for the buyer search pipeline, backed by the tiny
# search_synonyms table (seeded with Kenya-marketplace term pairs).
#
# Each pair is stored once and expanded bidirectionally: a row
# (term: "fridge", synonym: "refrigerator") matches a query containing either
# side and yields the other.
#
# Lookups run against individual normalized tokens AND the full normalized
# phrase, so multi-word terms like "spark plugs" also expand.
#
# All DB access is defensive: if the search_synonyms table is missing (e.g. the
# app boots before the migration runs) lookups fall back to the normalized
# base tokens so search keeps working.
#
class SearchSynonymExpander
  CACHE_PREFIX = 'search_synonym_expander'
  CACHE_TTL = 5.minutes

  class << self
    # @param query [String, nil] raw search query
    # @return [Array<String>] normalized query tokens plus synonym tokens, deduplicated
    #   (e.g. "Fridge" -> ["fridge", "refrigerator"])
    def terms_for(query)
      normalized = SearchQueryNormalizer.normalize(query)
      return [] if normalized.blank?

      synonyms = matching_pairs(normalized).flatten
      (normalized.split(' ') + synonyms.flat_map { |value| SearchQueryNormalizer.tokens(value) }).uniq
    end

    # @param query [String, nil] raw search query
    # @return [Array<String>] the normalized query plus matched terms/synonyms as
    #   whole-phrase alternatives (e.g. "fridge" -> ["fridge", "refrigerator"])
    def phrases_for(query)
      normalized = SearchQueryNormalizer.normalize(query)
      return [] if normalized.blank?

      ([normalized] + matching_pairs(normalized).flatten).uniq
    end

    private

    # All [term, synonym] pairs where either side matches any query token or the
    # full normalized phrase. Cached briefly - the table is tiny.
    def matching_pairs(normalized)
      Rails.cache.fetch("#{CACHE_PREFIX}:v1:#{normalized}", expires_in: CACHE_TTL) do
        fetch_pairs(lookup_keys(normalized))
      end
    end

    def lookup_keys(normalized)
      normalized.split(' ') + [normalized]
    end

    # Bidirectional: match stored pairs on either column.
    def fetch_pairs(keys)
      SearchSynonym.where(term: keys).or(SearchSynonym.where(synonym: keys)).pluck(:term, :synonym)
    rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished
      []
    end
  end
end
