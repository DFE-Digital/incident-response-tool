Rails.application.routes.draw do
  root to: "incidents#new"
  resources :incidents, only: %i[new create show] do
    resource :process_artefact, only: %i[create] do
      get :download
    end
    resource :runbook_artefact, only: %i[create]
  end

  get "/pages/:page", to: "pages#show"

  get "/404", to: "errors#not_found", via: :all
  get "/422", to: "errors#unprocessable_entity", via: :all
  get "/500", to: "errors#internal_server_error", via: :all
end
