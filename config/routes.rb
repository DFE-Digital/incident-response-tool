Rails.application.routes.draw do
  root to: "incidents#index"
  resources :incidents, only: %i[index new create show] do
    resource :process_artefact, only: %i[create] do
      get :download
    end
    resource :runbook_artefact, only: %i[create] do
      get :download
    end
    resource :review_artefact, only: %i[new create] do
      get :download
    end
  end

  get "/pages/:page", to: "pages#show"

  get "/404", to: "errors#not_found", via: :all
  get "/422", to: "errors#unprocessable_entity", via: :all
  get "/500", to: "errors#internal_server_error", via: :all
end
