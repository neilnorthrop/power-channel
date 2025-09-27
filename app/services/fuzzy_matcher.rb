# frozen_string_literal: true

class FuzzyMatcher
  # Simple Levenshtein distance for small lists
  def self.distance(a, b)
    a = (a || "").downcase
    b = (b || "").downcase
    return b.length if a.empty?
    return a.length if b.empty?
    m = Array.new(a.length + 1) { |i| i }
    (1..b.length).each do |j|
      prev = m[0]
      m[0] = j
      (1..a.length).each do |i|
        cur = m[i]
        cost = a[i - 1] == b[j - 1] ? 0 : 1
        m[i] = [
          m[i] + 1,      # deletion
          m[i - 1] + 1,  # insertion
          prev + cost    # substitution
        ].min
        prev = cur
      end
    end
    m[a.length]
  end

  def self.suggest(query, candidates, limit: 5)
    q = (query || "").downcase
    scores = candidates.map do |c|
      cd = c.downcase
      # Features
      lev = distance(q, cd)
      prefix = cd.start_with?(q) ? 0 : 1
      include = cd.include?(q) ? 0 : 1
      trigram = trigram_distance(q, cd)
      # Combine: lower is better
      score = lev * 2 + prefix * 1 + include * 1 + trigram
      [ c, [ score, cd.length ] ]
    end
    scores.sort_by { |(_, s)| s }.first(limit).map(&:first)
  end

  # Trigram distance: lower is better (1 - overlap) * scale
  def self.trigram_distance(a, b)
    ag = grams(a)
    bg = grams(b)
    return 10 if ag.empty? || bg.empty?
    inter = (ag & bg).size.to_f
    union = (ag | bg).size.to_f
    (1.0 - (inter / union)) * 5.0
  end

  def self.grams(s)
    s = s.gsub(/\s+/, " ")
    return [] if s.length < 2
    (0..s.length - 2).map { |i| s[i, 2] }.uniq
  end
end
