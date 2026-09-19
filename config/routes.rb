Rails.application.routes.draw do
  devise_for :users, skip: [:registrations]

  resources :professionals
  resources :rooms do
    collection do
      get :availability
    end
    member do
      get :calendar
    end
    resources :reservations, only: :create, controller: "room_reservations"
    resources :waitlist_entries, only: %i[index new create]
    resources :room_blocks, only: %i[create destroy]
  end
  resources :waitlist_entries, only: %i[index destroy] do
    member do
      post :convert
    end
  end
  resources :room_blocks, only: %i[index create destroy]
  resources :audit_events, only: %i[index show destroy] do
    collection do
      get :export
      post :bulk
    end
  end
  resources :outbound_emails, only: %i[index show new create destroy] do
    collection do
      post :bulk
      get :welcome, action: :edit_welcome, as: :edit_welcome
      patch :welcome, action: :update_welcome
    end
    member do
      post :resend
      post :forward
      get :download
      get :preview
    end
  end
  resources :bookings do
    collection do
      get :calendar
    end
    member do
      patch :cancel
      patch :reschedule
      patch :complete
    end
    resources :appointment_notes, only: %i[create destroy]
  end
  resources :invoices do
    collection do
      patch :bulk
    end
    member do
      patch :pay
      patch :refund
      patch :cancel
      patch :cancel_slots
    end
  end
  resources :reports, only: :index
  get "reports/occupancy", to: "reports#occupancy", as: :occupancy_reports
  get "reports/revenue", to: "reports#revenue", as: :revenue_reports
  get "reports/professionals", to: "reports#professionals", as: :professionals_reports
  get "reports/receivables", to: "reports#receivables", as: :receivables_reports
  get "reports/bookings", to: "reports#bookings", as: :bookings_reports
  get "reports/cancellations", to: "reports#cancellations", as: :cancellations_reports
  get "reports/aging", to: "reports#aging", as: :aging_reports
  get "reports/rooms", to: "reports#rooms", as: :rooms_reports
  get "reports/forecast", to: "reports#forecast", as: :forecast_reports
  get "reports/peak_hours", to: "reports#peak_hours", as: :peak_hours_reports
  get "reports/blocks", to: "reports#blocks", as: :blocks_reports
  get "reports/waitlist", to: "reports#waitlist", as: :waitlist_reports
  get "reports/patients", to: "reports#patients", as: :patients_reports
  get "reports/emails", to: "reports#emails", as: :emails_reports
  get "reports/activity", to: "reports#activity", as: :activity_reports
  resources :patients
  resources :users do
    member do
      post :invite
    end
  end
  resource :password_change, only: %i[edit update]
  resource :settings, only: %i[show edit update]

  root "dashboards#index"
  resources :dashboards
end
