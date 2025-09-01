import "@hotwired/turbo-rails"
import "controllers"

// Import page modules so they can bind to Turbo events
// and initialize on every visit without requiring a full reload.
import "pages/home"
import "pages/skills"
import "pages/inventory"
import "pages/buildings"
import "pages/crafting"
