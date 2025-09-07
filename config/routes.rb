Rails.application.routes.draw do
  root "game#index"
  get "/inventory", to: "game#inventory", as: :inventory
  get "/skills", to: "game#skills", as: :skills
  get "/crafting", to: "game#crafting", as: :crafting
  get "/buildings", to: "game#buildings", as: :buildings

  devise_for :users, controllers: { registrations: "api/v1/registrations" }

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
end
