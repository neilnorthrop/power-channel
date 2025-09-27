# frozen_string_literal: true

class SuggestionService
  # Enrich DB validator report with name suggestions when feasible.
  # Input: { section => [ "message", ... ] }
  # Output: { section => [ { message: String, suggestions: [String] } | String ] }
  def self.enrich(report)
    out = {}
    report.each do |section, issues|
      out[section] = issues.map { |msg| enrich_issue(section, msg) }
    end
    out
  end

  def self.enrich_issue(section, message)
    name = extract_quoted_name(message)
    model = model_for_section_and_message(section, message)
    if name && model
      attr = (model == Flag ? :slug : :name)
      candidates = model.limit(500).pluck(attr) # cap for safety
      suggests = FuzzyMatcher.suggest(name, candidates, limit: 3)
      { message: message, suggestions: suggests }
    else
      message
    end
  end

  def self.extract_quoted_name(message)
    # Try to find a token in single quotes: "'Name'"
    m = message.to_s.match(/'([^']+)'/)
    m && m[1]
  end

  def self.model_for_section_and_message(section, message)
    s = section.to_s
    txt = message.to_s
    # Heuristics based on content
    if txt.include?("Action") || s == "actions"
      Action
    elsif txt.include?("Resource") || s == "resources"
      Resource
    elsif txt.include?("Item") || s == "items"
      Item
    elsif txt.include?("Skill") || s == "skills"
      Skill
    elsif txt.include?("Building") || s == "buildings"
      Building
    elsif txt.include?("Flag") || s == "flags"
      Flag
    elsif txt.include?("Recipe") || s == "recipes"
      Recipe
    else
      nil
    end
  end
end
