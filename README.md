# AetherForge

AetherForge is a web-based crafting and progression game where players perform actions to gather resources, craft items, and unlock new skills and abilities.

## Core Game Concepts

The primary gameplay loop revolves around the following concepts:

*   **Actions:** The primary way users interact with the game. Actions, such as "Gather Wood" or "Collect Taxes," have a cooldown and grant resources and experience to the user.
*   **Resources:** Materials gathered from actions. Resources are used to craft items.
*   **Items:** Craftable objects that can provide passive benefits or active effects.
*   **Crafting:** The process of turning resources into items, based on recipes.
*   **Skills:** Passive abilities that users can unlock to improve their actions, such as increasing resource gain or decreasing cooldowns.
*   **Effects:** Temporary buffs or debuffs that can be applied to users, often from items.
*   **Buildings:** Structures that users can build to unlock new actions or provide other benefits.

## System Architecture

The application is a standard Ruby on Rails application with a PostgreSQL database. The core business logic is encapsulated in service objects, which are called by the controllers. The frontend is a simple, server-rendered application that communicates with the backend through a JSON API. Real-time updates are pushed to the client using Action Cable.

## Data Models

The following is a breakdown of the core data models in the application:

*   **User:** The central model of the application. It is associated with all other core models and contains the logic for experience gain and leveling up.
    *   **Attributes:** `email`, `encrypted_password`, `level`, `experience`, `skill_points`.
*   **Action:** Represents an activity a user can perform.
    *   **Attributes:** `name`, `description`, `cooldown`.
    *   **Associations:** `has_many :resources`, `has_many :effects`.
*   **Resource:** Represents a material that can be gathered.
    *   **Attributes:** `name`, `description`, `base_amount`, `drop_chance`.
    *   **Associations:** `belongs_to :action`, `has_many :recipe_resources`.
*   **Item:** A craftable object.
    *   **Attributes:** `name`, `description`.
    *   **Associations:** `has_one :recipe`, `has_many :effects`.
*   **Recipe:** Defines the resources required to craft an item.
    *   **Attributes:** `quantity`.
    *   **Associations:** `belongs_to :item`, `has_many :recipe_resources`.
*   **RecipeResource:** A join model that specifies the quantity of a resource needed for a recipe.
*   **Skill:** A passive ability that can be unlocked by a user.
    *   **Attributes:** `name`, `description`, `cost`, `effect`, `multiplier`.
*   **Effect:** A temporary buff or debuff.
    *   **Attributes:** `name`, `description`, `duration`.
    *   **Associations:** `belongs_to :effectable, polymorphic: true`.
*   **ActiveEffect:** A join model that applies an effect to a user with an expiration time.
*   **Building:** A structure that can be built by a user.
    *   **Attributes:** `name`, `description`, `cost`.

## Getting Started

### Prerequisites

*   Ruby 3.4.0
*   PostgreSQL

### Installation and Setup

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/neilnorthrop/power-channel.git
    cd AetherForge
    ```

2.  **Install dependencies:**
    ```bash
    bundle install
    ```

3.  **Create and set up the database:**
    ```bash
    rails db:create
    rails db:migrate
    rails db:seed
    ```

4.  **Run the test suite:**
    ```bash
    rails test
    ```

5.  **Start the server:**
    ```bash
    rails server
    ```

## How to Add a New Game Element

This section provides a step-by-step guide for adding a new interactive element to the game.

### Adding a New Action

1.  **Create a new Action record:** Add a new entry to `db/seeds.rb` for your action.
2.  **Create a new Resource record:** Add a new entry to `db/seeds.rb` for the resource that the action will grant. Make sure to associate it with the new action.
3.  **Run the seeds:** `rails db:seed`
4.  **Update the frontend:** Add the new action to the appropriate view so that users can interact with it.

### Adding a New Item

1.  **Create a new Item record:** Add a new entry to `db/seeds.rb`.
2.  **Create a new Recipe record:** Add a new entry to `db/seeds.rb`, associating it with the new item.
3.  **Create RecipeResource records:** Add entries to `db/seeds.rb` to specify the resources and quantities needed for the recipe.
4.  **Run the seeds:** `rails db:seed`
5.  **Update the frontend:** Add the new item and recipe to the crafting interface.

## Architectural Principles

*   **Service-Oriented Logic:** Core business logic is encapsulated in service objects (e.g., `ActionService`, `CraftingService`) to keep controllers thin and logic organized.
*   **Data-Driven Design:** Game elements are designed to be configurable through the database (e.g., skill multipliers) to allow for easy balancing and expansion.
*   **Strategy Pattern for Extensibility:** Complex, polymorphic logic (like skill effects) is handled by the Strategy pattern to ensure maintainability and extensibility.

## Developer Workflow

*   **Code Style:** This project uses `rubocop-rails-omakase`. Please run `bundle exec rubocop` before submitting code.
*   **Testing:** All new models and services should be accompanied by unit tests.
*   **Seeding:** The `db/seeds.rb` file is the source of truth for game data. Use it to populate your development environment.
