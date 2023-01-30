Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      post 'ask/create'
    end
  end
  root 'homepage#index'
end
