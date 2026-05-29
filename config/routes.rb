Rails.application.routes.draw do
  # Redirect to localhost from 127.0.0.1 to use same IP address with Vite server
  constraints(host: "127.0.0.1") do
    get "(*path)", to: redirect { |_params, req| "#{req.protocol}localhost:#{req.port}#{req.fullpath}" }
  end
  resource :session
  resources :passwords, param: :token
  resources :registrations, only: %i[new create]
  root "dashboard#index"

  namespace :admin do
    root "dashboard#index"
    resources :invitations, only: :create
    resource :ai_controls, only: %i[show update], controller: "/ai_controls"
    resources :models, only: %i[index create update], controller: "/models"

    if Rails.env.development?
      get "first_time_flow_preview", to: "/development/previews#first_time_flow", as: :first_time_flow_preview
    end
  end

  mount MissionControl::Jobs::Engine, at: "/admin/jobs"
  mount ActionCable.server, at: "/cable"

  resources :transactions, only: %i[index update] do
    patch :bulk_update, on: :collection
    post :chat, on: :collection
  end
  get "spending", to: "spending#index", as: :spending
  resources :budgets, only: %i[index update]
  resources :subcategories, only: %i[index create destroy]
  resources :saved_transaction_queries, only: %i[create destroy]
  resources :imports, only: %i[index create] do
    get :preview, on: :member
    post :commit, on: :member
    get :download, on: :member
  end
  resources :insights, only: %i[index create]
  get "offline", to: "offline#show", as: :offline
  get "offline/snapshot.json", to: "offline#snapshot", as: :offline_snapshot, defaults: { format: :json }
  resource :settings, only: %i[show update]
  resource :ai_preferences, only: %i[show update]
  resource :onboarding, only: :update, controller: :onboarding
  resources :ai_chats, only: %i[index show]
  resource :classifications, only: :create
  resources :classification_runs, only: :show do
    patch :cancel, on: :member
    patch :dismiss, on: :member
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "manifest.json" => "rails/pwa#manifest", as: :pwa_manifest, defaults: { format: :json }
  get "service-worker.js" => "rails/pwa#service_worker", as: :pwa_service_worker, defaults: { format: :js }

  # Defines the root path route ("/")
  # root "posts#index"
end
