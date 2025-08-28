# lib/tasks/assets.rake
namespace :dev do
  desc "Precompile assets (development) and sync importmap pins"
  task :rebuild_assets do
    sh "bin/rails assets:clobber"
    sh "bin/rails assets:precompile"
    sh "bin/importmap json > importmap.json"
    sh "WRITE=1 bin/sync_importmap"
    puts "Assets rebuilt and importmap synced."
  end
end
