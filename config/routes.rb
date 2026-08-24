Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  get "docs" => redirect("/docs/index.html")

  mount MissionControl::Jobs::Engine, at: "/jobs"

  namespace :api do
    namespace :v1 do
      resources :tags, only: %i[index show create update destroy]
      resources :categories, only: %i[index show create update destroy]
      resources :institutions, only: %i[index show create update destroy]
      resources :accounts, only: %i[index show create update destroy]
      resources :credit_cards, only: %i[index show create update destroy]
      resources :monthly_statements, only: %i[index]
      resources :transactions, only: %i[index show create update destroy] do
        member do
          post :cancel
        end

        resources :recurrences, only: %i[create], module: :transaction
      end

      namespace :user do
        resource :registrations, only: %i[create]
        resource :authentications, only: %i[create]
        resource :accounts, only: %i[destroy]
        resource :profiles, only: %i[update]

        namespace :email do
          resource :confirmations, only: %i[create]
          resource :changes, only: %i[update]
        end

        namespace :password do
          resource :changes, only: %i[update]
          resource :resets, only: %i[create update]
        end

        namespace :session do
          resource :refreshes, only: %i[update]
          resource :revokes, only: %i[destroy]
        end
      end
    end
  end
end
