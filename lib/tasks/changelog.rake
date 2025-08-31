# lib/tasks/changelog.rake

namespace :changelog do
  desc "Update CHANGELOG.md from git history (file changes only; no commit messages)"
  task :update do
    root = File.expand_path("../..", __dir__)
    changelog_path = File.join(root, "CHANGELOG.md")

    unless File.exist?(changelog_path)
      abort "CHANGELOG.md not found in project root"
    end

    content = File.read(changelog_path)
    # Find newest recorded date (format '## YYYY-MM-DD')
    newest = content.scan(/^##\s+(\d{4}-\d{2}-\d{2})/).flatten.first
    # Use ISO-8601 with 'T' to avoid shell quoting issues
    since_opt = newest ? "--since=#{newest}T00:00:00" : nil

    # Pull git history with names and statuses, grouped by date
    # Quote the pretty arg so the shell does not split `%ad` as a separate token
    pretty = "'--pretty=format:__COMMIT__ %ad'"
    cmd = [
      "git", "log", "--date=short", since_opt,
      pretty, "--name-status"
    ].compact.join(" ")

    log = `#{cmd}`
    if $?.exitstatus != 0
      abort "Failed to run git log"
    end

    # Build structure: date => { category => { added:[], modified:[], deleted:[] } }
    by_date = Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = { added: [], modified: [], deleted: [] } } }
    current_date = nil
    log.each_line do |line|
      line = line.strip
      if line.start_with?("__COMMIT__ ")
        current_date = line.split(" ", 2)[1]
        next
      end
      next if line.empty? || current_date.nil?
      # Parse name-status: e.g., "A\tpath", "M\tpath", "D\tpath"
      status, path = line.split(/\s+/, 2)
      next unless path
      change = case status
      when "A" then :added
      when "D" then :deleted
      else :modified
      end
      category = case path
      when %r{\Aapp/javascript/} then "Frontend"
      when %r{\Aapp/views/} then "Views"
      when %r{\Aconfig/importmap\.rb\z}, %r{\Alib/tasks/assets\.rake\z} then "Importmap/Assets"
      when %r{\Alib/tasks/} then "Rake Tasks"
      when %r{\Aapp/services/} then "Services"
      when %r{\Aapp/controllers/} then "Controllers"
      when %r{\Aapp/models/} then "Models"
      when %r{\Adb/seeds\.rb\z} then "Seeds"
      when %r{\Atest/} then "Tests"
      when %r{\Aconfig/} then "Config"
      else "Other"
      end
      by_date[current_date][category][change] << path
    end

    # Remove dates already in changelog (<= newest); keep only strictly newer dates
    if newest
      by_date.select! { |date, _| date > newest }
    end

    if by_date.empty?
      puts "[changelog:update] No changes to append."
      next
    end

    # Build new sections in reverse chronological order
    sections = []
    by_date.keys.sort.reverse.each do |date|
      sections << "## #{date}\n\n"
      by_date[date].sort.each do |category, changes|
        added = changes[:added]
        modified = changes[:modified]
        deleted = changes[:deleted]
        next if added.empty? && modified.empty? && deleted.empty?
        sections << "- #{category}\n"
        unless added.empty?
          sections << "  - Added:\n"
          added.uniq.first(20).each { |p| sections << "    - #{p}\n" }
          sections << "    - … (#{(added.uniq.size - 20)}) more\n" if added.uniq.size > 20
        end
        unless modified.empty?
          sections << "  - Modified:\n"
          modified.uniq.first(20).each { |p| sections << "    - #{p}\n" }
          sections << "    - … (#{(modified.uniq.size - 20)}) more\n" if modified.uniq.size > 20
        end
        unless deleted.empty?
          sections << "  - Deleted:\n"
          deleted.uniq.first(20).each { |p| sections << "    - #{p}\n" }
          sections << "    - … (#{(deleted.uniq.size - 20)}) more\n" if deleted.uniq.size > 20
        end
      end
      sections << "\n"
    end

    # Insert sections after the header line
    lines = content.lines
    header_index = lines.find_index { |l| l.start_with?("# Changelog") }
    insert_at = header_index ? header_index + 2 : 0
    new_content = lines[0...insert_at].join + sections.join + lines[insert_at..-1].join
    File.write(changelog_path, new_content)
    puts "[changelog:update] Appended #{by_date.keys.size} date section(s) to CHANGELOG.md"
  end
end
