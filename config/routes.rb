Rails.application.routes.draw do
  root to: 'homepage#index'

  get 'question/:id', to: 'homepage#index'

  namespace :api do
    namespace :v1 do
      get 'questions/:id', to: 'ask#show'
      post 'ask', to: 'ask#create'
    end
  end
end
