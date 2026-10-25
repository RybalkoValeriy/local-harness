Rails.application.routes.draw do
  root "projects#index"
  get "directories", to: "directories#index"
  resources :projects, only: %i[index create show] do
    get :files, on: :member, to: "project_files#index"
    get :file, on: :member, to: "project_files#show"
    resources :conversations, only: %i[show create] do
      post :run, on: :member
    end
  end
  resources :conversations, only: %i[index show create] do
    post :run, on: :member
  end
  get "connection", to: "conversations#connection"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
