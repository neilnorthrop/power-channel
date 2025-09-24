begin
  require "rubocop/rake_task"

  namespace :rubocop do
    RuboCop::RakeTask.new(:run) do |task|
      task.options = [ "--display-cop-names" ]
    end
  end

  desc "Run RuboCop"
  task rubocop: "rubocop:run"
rescue LoadError
  # RuboCop not available; define a placeholder task
  task :rubocop do
    warn "RuboCop is not installed. Add it to your Gemfile to use this task."
  end
end
