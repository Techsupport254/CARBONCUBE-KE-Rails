# frozen_string_literal: true

# Seed data for development/staging. Every block below is idempotent
# (safe to re-run: uses find_or_create_by!).

# ---------------------------------------------------------------------------
# Search synonyms: Kenya-marketplace term pairs for SearchSynonymExpander.
# Each pair is stored once - expansion is bidirectional, so either side of a
# pair matches in a query. Terms are written in normalized form (lowercase,
# spaces instead of punctuation) to match SearchQueryNormalizer output.
# ---------------------------------------------------------------------------
search_synonym_pairs = [
  %w[blender juicer],
  %w[fridge refrigerator],
  %w[freezer deep freezer],
  %w[tyre tire],
  %w[earphones earbuds],
  %w[earphones headphones],
  %w[charger adapter],
  %w[tv television],
  %w[laptop notebook],
  %w[woofer subwoofer],
  %w[sub subwoofer],
  %w[soundbar sound bar],
  %w[sofa couch],
  %w[cooker stove],
  %w[microwave microwave oven],
  %w[washing machine washer],
  %w[dryer tumble dryer],
  %w[gearbox transmission],
  %w[bonnet hood],
  %w[bumper fender],
  %w[motorbike motorcycle],
  %w[boda motorbike],
  %w[screen display],
  %w[plugs spark plugs],
  %w[sneakers trainers],
  %w[sneakers sport shoes],
  %w[carpet rug],
  %w[decoder set top box],
  %w[mifi router],
  %w[generator genset],
  %w[iron box iron],
  %w[crib cot],
  %w[play station playstation],
  %w[meko gas burner]
]

search_synonym_pairs.each do |term, synonym|
  SearchSynonym.find_or_create_by!(term: term, synonym: synonym)
end
