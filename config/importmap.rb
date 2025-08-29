# Pin npm packages by running ./bin/importmap

# Map bare specifiers to asset paths
pin "application", to: "application.js", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin "@rails/actioncable", to: "actioncable.esm.js"

# Stimulus controllers
pin "controllers", to: "controllers/index.js"
pin_all_from "app/javascript/controllers", under: "controllers"

# Game bootstrap module
pin "game", to: "game/index.js"
