# frozen_string_literal: true

# Normalizes raw buyer search queries into a canonical lowercase token string
# for the search pipeline (pg_search input, synonym lookups, cache keys).
#
# Behaviour:
#   * downcases
#   * converts every non-alphanumeric character (punctuation such as / - , . ( ) ')
#     to a space, so "h/p" -> "h p" and "spark-plugs" -> "spark plugs"
#   * inserts a space between a digit and a glued-on known unit so "1.5l",
#     "1.5 l" and "5kg" tokenize consistently (e.g. "1 5 l", "5 kg")
#   * collapses runs of whitespace and trims
#
# Noise/stop words are NOT removed - downstream stages decide significance.
#
class SearchQueryNormalizer
  # Unit suffixes recognised when glued to a number (e.g. "5kg", "1.5l", "32inch").
  # Ordered longest-first so multi-letter units win the alternation.
  UNITS = %w[inch kw gb tb mb mm cm kg hp l g w m].freeze

  UNIT_PATTERN = /(\d)(#{UNITS.join('|')})\b/

  class << self
    # @param query [String, nil] raw search query
    # @return [String] normalized query
    def normalize(query)
      query.to_s
           .downcase
           .gsub(/[^\p{Alnum}\s]/, ' ')
           .gsub(UNIT_PATTERN, '\1 \2')
           .squish
    end

    # @param query [String, nil] raw search query
    # @return [Array<String>] normalized tokens
    def tokens(query)
      normalize(query).split(' ')
    end
  end
end
