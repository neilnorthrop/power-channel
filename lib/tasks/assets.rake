# lib/tasks/assets.rake
namespace :dev do
  desc "Precompile assets (development)"
  task :rebuild_assets do
    sh "bin/rails assets:clobber"
    sh "bin/rails assets:precompile"
    puts "Assets rebuilt. Importmap pins are managed in config/importmap.rb."
  end
end
