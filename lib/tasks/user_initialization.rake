# lib/tasks/user_initialization.rake

namespace :users do
  require "set"
  # Determines if a user already appears to have defaults applied.
  # Defaults are considered present if the user has any user_resources or user_actions.
  def defaults_already_set?(user)
    user.user_resources.exists? || user.user_actions.exists?
  end

  desc "Initialize defaults for a single user id. Usage: rake users:init_one[ID,FORCE] or FORCE=1 rake users:init_one[ID]"
  task :init_one, [ :id, :force ] => :environment do |_t, args|
    id = args[:id]
    abort "Usage: rake users:init_one[ID,FORCE]" if id.nil?

    force_flag = args[:force]
    # Support FORCE as positional arg or ENV var
    force = ActiveModel::Type::Boolean.new.cast(force_flag.presence || ENV["FORCE"]) || false

    user = User.find_by(id: id)
    if user.nil?
      abort "User with id=#{id} not found"
    end

    if defaults_already_set?(user) && !force
      puts "[users:init_one] Skipping user #{user.id} (#{user.email}) — defaults already set. Pass FORCE=1 to override."
      next
    end

    UserInitializationService.new(user).initialize_defaults
    puts "[users:init_one] Initialized defaults for user #{user.id} (#{user.email})."
  end

  # Create missing user_actions for the given user for all current Actions.
  # Returns the number of associations created.
  def ensure_actions_for_user(user)
    existing_ids = user.user_actions.pluck(:action_id).to_set
    to_create = []
    now = Time.current
    Action.find_each do |action|
      next if existing_ids.include?(action.id)
      to_create << { user_id: user.id, action_id: action.id, created_at: now, updated_at: now }
    end
    if to_create.any?
      UserAction.insert_all(to_create)
      to_create.length
    else
      0
    end
  end

  # Create missing user_resources for all current Resources, setting amount to
  # the resource's base_amount. Returns the number of associations created.
  def ensure_resources_for_user(user)
    existing_ids = user.user_resources.pluck(:resource_id).to_set
    to_create = []
    now = Time.current
    Resource.find_each do |resource|
      next if existing_ids.include?(resource.id)
      to_create << { user_id: user.id, resource_id: resource.id, amount: resource.base_amount, created_at: now, updated_at: now }
    end
    if to_create.any?
      UserResource.insert_all(to_create)
      to_create.length
    else
      0
    end
  end

  # Optionally create missing user_items rows with quantity=0 for completeness.
  # By default, does nothing unless create_zero=true is passed.
  def ensure_items_for_user(user, create_zero: false, default_quantity: 0)
    return 0 unless create_zero
    existing_ids = user.user_items.pluck(:item_id).to_set
    to_create = []
    now = Time.current
    Item.find_each do |item|
      next if existing_ids.include?(item.id)
      to_create << { user_id: user.id, item_id: item.id, quantity: default_quantity, created_at: now, updated_at: now }
    end
    if to_create.any?
      UserItem.insert_all(to_create)
      to_create.length
    else
      0
    end
  end

  # Optionally grant all skills to a user (generally not recommended) unless
  # auto_grant=true is passed. Returns the number of skills granted.
  def ensure_skills_for_user(user, auto_grant: false)
    return 0 unless auto_grant
    existing_ids = user.user_skills.pluck(:skill_id).to_set
    to_create = []
    now = Time.current
    Skill.find_each do |skill|
      next if existing_ids.include?(skill.id)
      to_create << { user_id: user.id, skill_id: skill.id, created_at: now, updated_at: now }
    end
    if to_create.any?
      UserSkill.insert_all(to_create)
      to_create.length
    else
      0
    end
  end

  # Optionally grant all buildings to a user at a given level (default 1) unless
  # auto_grant=true is passed. Returns the number of buildings granted.
  def ensure_buildings_for_user(user, auto_grant: false, level: 1)
    return 0 unless auto_grant
    existing_ids = user.user_buildings.pluck(:building_id).to_set
    to_create = []
    now = Time.current
    Building.find_each do |building|
      next if existing_ids.include?(building.id)
      to_create << { user_id: user.id, building_id: building.id, level: level, created_at: now, updated_at: now }
    end
    if to_create.any?
      UserBuilding.insert_all(to_create)
      to_create.length
    else
      0
    end
  end

  desc "Initialize defaults for all users. Skips users that already have defaults."
  task init_all: :environment do
    total = 0
    skipped = 0
    initialized = 0

    User.find_each do |user|
      total += 1
      if defaults_already_set?(user)
        skipped += 1
        next
      end
      UserInitializationService.new(user).initialize_defaults
      initialized += 1
    end

    puts "[users:init_all] Processed #{total} users. Initialized: #{initialized}, Skipped: #{skipped}."
  end

  desc "Generate N users with X initialized. Usage: rake users:generate[N,X] PASS=optional_default_password"
  task :generate, [ :n, :x ] => :environment do |_t, args|
    if Rails.env.production?
      abort "[users:generate] This task is disabled in production."
    end
    require "securerandom"

    n = args[:n].to_i
    x = args[:x].to_i
    abort "Usage: rake users:generate[N,X]" if n <= 0 || x < 0 || x > n

    default_password = ENV.fetch("PASS", "password")
    encrypted = Devise::Encryptor.digest(User, default_password)

    created_initialized = 0
    created_uninitialized = 0

    x.times do |i|
      email = "gen_init_#{Time.now.to_i}_#{i}_#{SecureRandom.hex(3)}@example.com"
      User.create!(email: email, password: default_password, password_confirmation: default_password)
      created_initialized += 1
    end

    batch = []
    (n - x).times do |i|
      email = "gen_plain_#{Time.now.to_i}_#{i}_#{SecureRandom.hex(3)}@example.com"
      batch << {
        email: email,
        encrypted_password: encrypted,
        created_at: Time.current,
        updated_at: Time.current
      }
    end
    if batch.any?
      result = User.insert_all(batch)
      created_uninitialized = result.respond_to?(:count) ? result.count : batch.length
    end

    puts "[users:generate] Requested: #{n} users (#{x} initialized, #{n - x} uninitialized)."
    puts "[users:generate] Created: #{created_initialized} initialized, #{created_uninitialized} uninitialized."
    puts "[users:generate] Default password: #{default_password.inspect}"
  end

  desc "Show initialization status for every user (ID, email, initialized)"
  task status: :environment do
    total = 0
    initialized = 0
    uninitialized = 0

    rows = []
    User.find_each do |user|
      total += 1
      is_init = defaults_already_set?(user)
      initialized += 1 if is_init
      uninitialized += 1 unless is_init
      rows << [ user.id.to_s, user.email.to_s, (is_init ? "yes" : "no") ]
    end

    # Determine column widths for a neat table
    id_w = [ [ 2 ] + rows.map { |r| r[0].length } ].flatten.max
    email_w = [ [ 5 ] + rows.map { |r| r[1].length } ].flatten.max
    status_w = 11

    header = sprintf("%-#{id_w}s  %-#{email_w}s  %-#{status_w}s", "ID", "Email", "Initialized")
    puts header
    puts "-" * header.length

    rows.each do |id, email, status|
      puts sprintf("%-#{id_w}s  %-#{email_w}s  %-#{status_w}s", id, email, status)
    end

    puts "Totals: #{total} users — initialized: #{initialized}, uninitialized: #{uninitialized}"
  end

  desc "Ensure missing user_actions for a single user id. Usage: rake users:ensure_actions_one[ID]"
  task :ensure_actions_one, [ :id ] => :environment do |_t, args|
    id = args[:id]
    abort "Usage: rake users:ensure_actions_one[ID]" if id.nil?
    user = User.find_by(id: id)
    abort "User with id=#{id} not found" unless user
    unless defaults_already_set?(user)
      puts "[users:ensure_actions_one] Skipping user #{user.id} (#{user.email}) — defaults are not initialized."
      next
    end
    created = ensure_actions_for_user(user)
    puts "[users:ensure_actions_one] User #{user.id} (#{user.email}): created #{created} missing user_actions."
  end

  desc "Ensure missing user_actions for all users (idempotent)."
  task ensure_actions: :environment do
    total_users = 0
    total_created = 0
    not_initialized = 0
    User.find_each do |user|
      total_users += 1
      unless defaults_already_set?(user)
        not_initialized += 1
        puts "[users:ensure_actions] Skipping user #{user.id} (#{user.email}) — defaults are not initialized."
        next
      end
      total_created += ensure_actions_for_user(user)
    end
    puts "[users:ensure_actions] Processed #{total_users} users. Total user_actions created: #{total_created}. Skipped (not initialized): #{not_initialized}."
  end

  # Ensure user_resources for a single user
  desc "Ensure missing user_resources for a single user. Usage: rake users:ensure_resources_one[ID]"
  task :ensure_resources_one, [:id] => :environment do |_t, args|
    id = args[:id]
    abort "Usage: rake users:ensure_resources_one[ID]" if id.nil?
    user = User.find_by(id: id)
    abort "User with id=#{id} not found" unless user
    unless defaults_already_set?(user)
      puts "[users:ensure_resources_one] Skipping user #{user.id} (#{user.email}) — defaults are not initialized."
      next
    end
    created = ensure_resources_for_user(user)
    puts "[users:ensure_resources_one] User #{user.id} (#{user.email}): created #{created} missing user_resources."
  end

  # Ensure user_resources for all users
  desc "Ensure missing user_resources for all users (idempotent)."
  task ensure_resources: :environment do
    total_users = 0
    total_created = 0
    not_initialized = 0
    User.find_each do |user|
      total_users += 1
      unless defaults_already_set?(user)
        not_initialized += 1
        puts "[users:ensure_resources] Skipping user #{user.id} (#{user.email}) — defaults are not initialized."
        next
      end
      total_created += ensure_resources_for_user(user)
    end
    puts "[users:ensure_resources] Processed #{total_users} users. Total user_resources created: #{total_created}. Skipped (not initialized): #{not_initialized}."
  end

  # Ensure user_items rows exist with quantity=0 (opt-in via ITEMS_CREATE_ZERO=1)
  desc "Ensure missing user_items for all users (quantity=0). Set ITEMS_CREATE_ZERO=1 to enable."
  task ensure_items: :environment do
    create_zero = ActiveModel::Type::Boolean.new.cast(ENV["ITEMS_CREATE_ZERO"]) || false
    unless create_zero
      puts "[users:ensure_items] Skipping — set ITEMS_CREATE_ZERO=1 to create zero-quantity user_items."
      next
    end
    total_users = 0
    total_created = 0
    not_initialized = 0
    User.find_each do |user|
      total_users += 1
      unless defaults_already_set?(user)
        not_initialized += 1
        puts "[users:ensure_items] Skipping user #{user.id} (#{user.email}) — defaults are not initialized."
        next
      end
      total_created += ensure_items_for_user(user, create_zero: true)
    end
    puts "[users:ensure_items] Processed #{total_users} users. Total user_items created: #{total_created}. Skipped (not initialized): #{not_initialized}."
  end

  # Ensure user_skills (unlock all) — opt-in via AUTO_GRANT=1 (generally not recommended)
  desc "Ensure missing user_skills for all users (unlock all). Set AUTO_GRANT=1 to enable."
  task ensure_skills: :environment do
    auto = ActiveModel::Type::Boolean.new.cast(ENV["AUTO_GRANT"]) || false
    unless auto
      puts "[users:ensure_skills] Skipping — set AUTO_GRANT=1 to grant all skills to users."
      next
    end
    total_users = 0
    total_created = 0
    not_initialized = 0
    User.find_each do |user|
      total_users += 1
      unless defaults_already_set?(user)
        not_initialized += 1
        puts "[users:ensure_skills] Skipping user #{user.id} (#{user.email}) — defaults are not initialized."
        next
      end
      total_created += ensure_skills_for_user(user, auto_grant: true)
    end
    puts "[users:ensure_skills] Processed #{total_users} users. Total user_skills created: #{total_created}. Skipped (not initialized): #{not_initialized}."
  end

  # Ensure user_buildings — opt-in via AUTO_GRANT=1 and optional LEVEL
  desc "Ensure missing user_buildings for all users. Set AUTO_GRANT=1 to grant, LEVEL=<int> to choose level (default 1)."
  task ensure_buildings: :environment do
    auto = ActiveModel::Type::Boolean.new.cast(ENV["AUTO_GRANT"]) || false
    level = (ENV["LEVEL"].presence || 1).to_i
    unless auto
      puts "[users:ensure_buildings] Skipping — set AUTO_GRANT=1 to grant buildings to users."
      next
    end
    total_users = 0
    total_created = 0
    not_initialized = 0
    User.find_each do |user|
      total_users += 1
      unless defaults_already_set?(user)
        not_initialized += 1
        puts "[users:ensure_buildings] Skipping user #{user.id} (#{user.email}) — defaults are not initialized."
        next
      end
      total_created += ensure_buildings_for_user(user, auto_grant: true, level: level)
    end
    puts "[users:ensure_buildings] Processed #{total_users} users. Total user_buildings created: #{total_created}. Skipped (not initialized): #{not_initialized}."
  end
end

# Composite task to seed reference data and then ensure user actions
# Roadmap note: Task organization/naming guidance has moved to ROADMAP.md
# See: ROADMAP.md › "Tooling, CI/CD, Observability" › Task organization/naming
# (details include broader namespaces like data:seed_and_backfill, app:bootstrap)
namespace :app do
  desc "Run db:seed and users:ensure_actions (idempotent)"
  task seed_and_ensure_actions: :environment do
    %w[db:seed users:ensure_actions].each do |t|
      Rake::Task[t].reenable # allow re-running within the same process if needed
      Rake::Task[t].invoke
    end
  end

  desc "Run db:seed and users:ensure_resources (idempotent)"
  task seed_and_ensure_resources: :environment do
    %w[db:seed users:ensure_resources].each do |t|
      Rake::Task[t].reenable
      Rake::Task[t].invoke
    end
  end

  desc "Run db:seed and users:ensure_items (idempotent; requires ITEMS_CREATE_ZERO=1)"
  task seed_and_ensure_items: :environment do
    %w[db:seed users:ensure_items].each do |t|
      Rake::Task[t].reenable
      Rake::Task[t].invoke
    end
  end

  desc "Run db:seed and users:ensure_skills (idempotent; requires AUTO_GRANT=1)"
  task seed_and_ensure_skills: :environment do
    %w[db:seed users:ensure_skills].each do |t|
      Rake::Task[t].reenable
      Rake::Task[t].invoke
    end
  end

  desc "Run db:seed and users:ensure_buildings (idempotent; requires AUTO_GRANT=1)"
  task seed_and_ensure_buildings: :environment do
    %w[db:seed users:ensure_buildings].each do |t|
      Rake::Task[t].reenable
      Rake::Task[t].invoke
    end
  end

  desc "Run db:seed and all ensure tasks (actions, resources, items, skills, buildings)"
  task seed_and_ensure_all: :environment do
    tasks = %w[
      db:seed
      users:ensure_actions
      users:ensure_resources
      users:ensure_items
      users:ensure_skills
      users:ensure_buildings
    ]
    tasks.each do |t|
      Rake::Task[t].reenable
      Rake::Task[t].invoke
    end
  end
end
