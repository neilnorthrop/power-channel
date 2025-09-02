# frozen_string_literal: true

namespace :users do
  desc 'Ensure flags for all users (idempotent)'
  task ensure_flags: :environment do
    User.find_each do |user|
      EnsureFlagsService.evaluate_for(user)
    end
    puts 'Ensured flags for all users.'
  end

  desc 'Ensure flags for one user: users:ensure_flags_one[ID]'
  task :ensure_flags_one, [:id] => :environment do |_, args|
    user = User.find(args[:id])
    EnsureFlagsService.evaluate_for(user)
    puts "Ensured flags for user ##{user.id}."
  end
end

