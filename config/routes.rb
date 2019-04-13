Rails.application.routes.draw do
  get 'users/new'
  post '/callback' => 'linebot#callback'
end
