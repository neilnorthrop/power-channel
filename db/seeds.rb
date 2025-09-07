#!/usr/bin/env ruby
# Externalized, idempotent seeds via YAML content files under db/data.
#
# Usage:
#   bin/rails db:seed                 # apply content
#   DRY_RUN=1 bin/rails db:seed       # validate without writing
#   PRUNE=1  bin/rails db:seed        # remove recipe components not listed
#
# After seeding, consider backfilling associations (idempotent):
#   bin/rails users:ensure_actions
#   bin/rails users:ensure_resources
#   ITEMS_CREATE_ZERO=1 bin/rails users:ensure_items
#   AUTO_GRANT=1         bin/rails users:ensure_skills
#   AUTO_GRANT=1 LEVEL=1 bin/rails users:ensure_buildings

# For details and examples, see `SEEDS_REFERENCE_GUIDE.md`.

require Rails.root.join('lib', 'seeds', 'loader').to_s

dry_run = ENV['DRY_RUN'].present?
prune   = ENV['PRUNE'].present?

Seeds::Loader.apply!(dry_run: dry_run, prune: prune)

puts "Seeded (YAML): actions=#{Action.count}, resources=#{Resource.count}, skills=#{Skill.count}, items=#{Item.count}, buildings=#{Building.count}, recipes=#{Recipe.count}, flags=#{Flag.count}."
