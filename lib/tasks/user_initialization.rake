# lib/tasks/user_initialization.rake

namespace :users do
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
end
