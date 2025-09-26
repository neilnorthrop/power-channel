# frozen_string_literal: true

namespace :users do
  desc "Assign owner role to a user by email. Usage: rake users:assign_owner[email@example.com]"
  task :assign_owner, [:email] => :environment do |_, args|
    email = args[:email] || ENV["OWNER_EMAIL"]
    abort("Provide email as arg or OWNER_EMAIL env var") unless email

    user = User.find_by(email: email)
    abort("User not found: #{email}") unless user

    user.update!(role: :owner)
    puts "Assigned owner role to #{email}"
  end

  desc "Ensure there is an owner set via OWNER_EMAIL env var"
  task :ensure_owner => :environment do
    email = ENV["OWNER_EMAIL"]
    abort("Set OWNER_EMAIL to ensure an owner") unless email

    user = User.find_by(email: email)
    abort("User not found: #{email}") unless user

    if user.owner?
      puts "Already owner: #{email}"
    else
      user.update!(role: :owner)
      puts "Assigned owner role to #{email}"
    end
  end
end

