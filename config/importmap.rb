# Pin npm packages by running ./bin/importmap

pin "application", to: "application.js", preload: true

# Hotwire libs (explicit to compiled assets present under /assets)
pin "@hotwired/turbo-rails", to: "/assets/turbo-a1e3a50a.js", preload: true
pin "@hotwired/stimulus", to: "/assets/stimulus-d59b3b7f.js", preload: true
pin "@hotwired/stimulus-loading", to: "/assets/stimulus-loading-1fc53fe7.js", preload: true

# Stimulus controllers
pin "controllers", to: "controllers/index.js"
pin_all_from "app/javascript/controllers", under: "controllers"

# Page modules
pin_all_from "app/javascript/pages", under: "pages"
pin "pages/home", to: "pages/home.js"
pin "pages/inventory", to: "pages/inventory.js"
pin "pages/skills", to: "pages/skills.js"
pin "pages/crafting", to: "pages/crafting.js"
pin "pages/buildings", to: "pages/buildings.js"
pin "pages/util", to: "pages/util.js"

# Action Cable ESM
pin "@rails/actioncable", to: "actioncable.esm.js"
