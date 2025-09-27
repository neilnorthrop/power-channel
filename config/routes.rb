Rails.application.routes.draw do
  root "game#index"
  get "/inventory", to: "game#inventory", as: :inventory
  get "/skills", to: "game#skills", as: :skills
  get "/buildings", to: "game#buildings", as: :buildings

  devise_for :users, controllers: { registrations: "api/v1/registrations" }

  namespace :owner do
    get "/", to: "dashboard#index", as: :dashboard
    resources :users, only: [ :index, :update ] do
      post :suspend, on: :member
      post :unsuspend, on: :member
      post :grant_resource, on: :member
      post :add_flag, on: :member
      delete :remove_flag, on: :member
    end
    resources :announcements, only: [ :index, :new, :create, :edit, :update ] do
      post :toggle, on: :member
      post :publish_now, on: :member
      post :publish_in, on: :member
    end
    resources :impersonations, only: [] do
      post :start, on: :member
      post :stop, on: :collection
    end
    resources :audit_logs, only: [ :index ]
    resources :suspension_templates, only: [ :index, :create, :edit, :update, :destroy ]
    resources :content, controller: "content" do
      collection do
        get :index
        post :export
        post :export_validate
      end
    end
    resources :recipes, only: [ :index, :new, :create, :edit, :update ] do
      member do
        get :duplicate
      end
    end
    post "recipes/:id/validate", to: "recipes#validate_all", as: :validate_recipe
    post "recipes/validate", to: "recipes#validate_new", as: :validate_recipes
    resources :flags, only: [ :index, :new, :create, :edit, :update ]
    post "flags/:id/validate", to: "flags#validate_all", as: :validate_flag
    post "flags/validate", to: "flags#validate_new", as: :validate_flags
    resources :dismantles, only: [ :index, :new, :create, :edit, :update ]
    post "dismantles/:id/validate", to: "dismantles#validate_all", as: :validate_dismantle
    resources :effects do
      member do
        get :duplicate
      end
    end
    post "effects/:id/validate", to: "effects#validate_all", as: :validate_effect
    post "effects/validate", to: "effects#validate_all", as: :validate_effects
    resources :action_item_drops, only: [ :index, :update ]
    post "action_item_drops/:id/validate", to: "action_item_drops#validate", as: :validate_action_item_drops
    get "lookups/suggest", to: "lookups#suggest"
    get "lookups/exists", to: "lookups#exists"
    resources :seeds, only: [ :index ] do
      collection do
        post :validate
        post :validate_db
        post :export_all
        post :run_db_validation
      end
    end
  end

  namespace :api do
    namespace :v1 do
      post "authenticate", to: "authentication#create"
      resources :resources, only: [ :index ]
      resources :user_resources, only: [ :index ]
      resources :actions, only: [ :index, :create, :update ]
      get "/user", to: "users#show"
      resources :skills, only: [ :index, :create ]
      resources :items, only: [ :index, :create ] do
        post "use", on: :member
      end
      resources :crafting, only: [ :index, :create ]
      resources :dismantle, only: [ :create ]
      resources :buildings, only: [ :index, :create, :update ]
      resources :events, only: [ :index ]
    end
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
  get "/favicon.ico", to: "application#favicon"

  # SPA-style fallback: send unknown HTML routes to game#index
  get "*path", to: "game#index", constraints: ->(req) {
    req.format.html? &&
    !req.path.start_with?("/rails/") &&
    !req.path.start_with?("/cable")
  }
end
