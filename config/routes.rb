Rails.application.routes.draw do
 get "/health", to: "health#show"
 resources :books, only: [:index, :create, :show] do
  resources :sessions, only: [:create]
 end
end
