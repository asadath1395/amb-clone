Rails.application.routes.draw do
  root to: 'homepage#index'

  get 'question/:id', to: 'homepage#index'

  namespace :api do
    namespace :v1 do
      post 'ask/create'
    end
  end
end
