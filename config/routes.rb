Rails.application.routes.draw do
  namespace :api do
    get "health", to: "health#show"

    namespace :auth do
      post "signup",              to: "authentication#signup"
      post "login",               to: "authentication#login"
      post "social",              to: "authentication#social"
      get  "verify_email",        to: "authentication#verify_email"
      post "resend_verification", to: "authentication#resend_verification"
      post "refresh",             to: "authentication#refresh"
      post "logout",              to: "authentication#logout"
      get  "me",                  to: "authentication#me"
    end

    # Profile (Phase 2)
    resource :profile, only: [:show, :update], controller: "profiles" do
      delete "remove_photo", on: :member
      get    "download",     on: :member
    end

    # Subscriptions (Phase 3)
    resources :subscriptions, only: [] do
      collection do
        get  "plans"
        get  "current"
        get  "history"
        get  "success"
        post "checkout"
      end
    end

    # Stripe Webhook
    post "webhooks/stripe", to: "webhooks#stripe"

    # Tutors & Calls (Phase 4)
    resources :tutors, only: [:index, :show] do
      collection do
        patch "toggle_status"
      end
    end

    resources :calls, only: [] do
      collection do
        post   "start"
        post   "end_call"
        post   "heartbeat"
        get    "active"
        get    "history"
      end
    end

    # Admin (Phase 5)
    namespace :admin do
      get "stats", to: "dashboard#stats"
      get "recent_activity", to: "dashboard#recent_activity"
      resources :users, only: [:index, :show, :update] do
        member do
          post "ban"
          post "unban"
        end
      end
    end
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
