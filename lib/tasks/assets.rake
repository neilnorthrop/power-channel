# lib/tasks/assets.rake
namespace :dev do
  desc "Precompile assets (development) and sync importmap pins"
  task :rebuild_assets do
    sh "bin/rails assets:clobber"
    sh "bin/rails assets:precompile"
    # Ensure compiled controllers index files don't contain extensionless
    # relative imports like `./application` which the browser resolves to
    # `/assets/controllers/application` (leading to 404/text/plain). Replace
    # them with the importmap specifier so the browser will resolve via the
    # importmap to the correct hashed bundle.
    Dir.glob(File.join("public", "assets", "controllers", "index-*.js")).each do |file|
      text = File.read(file)
      new = text.gsub(/import\s+\{\s*application\s*\}\s+from\s+["']\.\/application(?:-[0-9a-f]+\.js)?["']/, 'import { application } from "controllers/application"')
      if text != new
        File.write(file, new)
        puts "Patched compiled controllers index: #{file}"
      end
    end
    sh "bin/importmap json > importmap.json"
    sh "WRITE=1 bin/sync_importmap"
    puts "Assets rebuilt and importmap synced."
  end
end
