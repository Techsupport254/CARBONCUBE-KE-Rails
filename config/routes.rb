
Rails.application.routes.draw do


  root to: 'application#home'
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.

  #========================================Public namespace for public-specific functionality==========================================#
  
  get "up" => "rails/health#show", as: :rails_health_check
  post 'auth/login', to: 'authentication#login'
  resources :banners, only: [:index]
  resources :ads, only: [:index, :show] do
    get 'reviews', to: 'reviews#index', on: :member
  end

  # Routes for logging ad searches
  resources :ad_searches, only: [:create]

  # Routes for logging click events
  resources :click_events, only: [:create]
  
  # Routes for logging subcategory clicks
  resources :subcategory_clicks, only: [:create]
  
  # Routes for source tracking
  post 'source-tracking/track', to: 'source_tracking#track'
  get 'source-tracking/analytics', to: 'source_tracking#analytics'
  
  # Redirect /track to /source-tracking/track for compatibility
  post 'track', to: 'source_tracking#track'
  get 'analytics', to: 'source_tracking#analytics'
  
  resources :incomes, only: [:index]
  resources :sectors, only: [:index]
  resources :educations, only: [:index]
  resources :employments, only: [:index]
  resources :tiers, only: [:index]

  # Mpesa payment routes
  post "payments/validate", to: "mpesa#validate_payment"
  post "payments/confirm", to: "mpesa#confirm_payment"
  
  # Routes for counties and sub_counties
  resources :counties, only: [:index] do
    get 'sub_counties', on: :member # /counties/:id/sub_counties
  end

  # Routes for age_groups
  resources :age_groups, only: [:index]

  # Routes for password OTPs
  post '/password_resets/request_otp', to: 'password_resets#request_otp'
  post '/password_resets/verify_otp', to: 'password_resets#verify_otp'

  # Sign-Up OTP routes
  resources :email_otps, only: [:create] do
    collection do
      post :verify
    end 
  end

  # Route for seller ads viewing
  # This route allows viewing ads for a specific seller
  resources :sellers, only: [] do
    get 'ads', to: 'sellers#ads'
  end

  # Routes for document types
  resources :document_types, only: [:index]

  # Routes for internal user exclusions and removal requests
  resources :internal_user_exclusions, only: [:create] do
    collection do
      get 'check/:device_hash', to: 'internal_user_exclusions#check_status'
      patch 'update_status/:device_hash', to: 'internal_user_exclusions#update_status'
    end
  end


  #========================================Admin namespace for admin-specific functionality==========================================#
  namespace :admin do
    namespace :seller do
      get ':seller_id/profile', to: 'profiles#show'
      get ':seller_id/ads', to: 'ads#index'
      get ':seller_id/ads/:ad_id/reviews', to: 'reviews#index'
      get ':seller_id/orders', to: 'orders#index_for_seller'
    end

    namespace :buyer do
      get ':buyer_id/profile', to: 'profiles#show'
      get ':buyer_id/orders', to: 'orders#index_for_buyer'
    end
    

    namespace :rider do
      get ':rider_id/profile', to: 'profiles#show'
      get ':rider_id/orders', to: 'orders#index_for_rider'
    end

    resources :orders, only: [:index, :show, :destroy] do
      member do
        put 'update-status', to: 'orders#update_status'
      end
    end
    
    resources :categories
    resources :subcategories
    resources :ads do
      collection do
        get 'search'
        get 'flagged'
      end
      member do
        patch 'flag'
        patch 'restore'
      end
    end

    resources :cms_pages
    resources :sellers do
      member do
        put 'block'
        put 'unblock'
        get 'analytics'
        get 'orders', to: 'sellers#orders'
        get 'ads'
        get 'reviews'
        post :verify_document
      end
    end

    resources :buyers do
      member do
        put 'block'
        put 'unblock'
      end
    end

    resources :riders do 
      member do
        put 'block'
        put 'unblock'
        put 'assign'
        put 'analytics'
        get 'orders', to: 'riders#orders'
      end
    end

    resources :conversations, only: [:index, :show, :create] do
      resources :messages, only: [:index, :create]
    end

    resources :analytics
    resources :reviews
    resources :abouts
    resources :faqs
    resources :banners
    resources :promotions, except: [:new, :edit]
    get 'identify', to: 'admins#identify'
    resource :profile, only: [:show, :update] do
      collection do
        post 'change-password'
      end
    end
    resources :notifications, only: [:index, :create]
    resources :ad_searches, only: [:index, :show, :destroy]
    resources :click_events, only: [:index, :show, :destroy]
    resources :tiers, only: [:index, :show, :create, :update, :destroy]
    resources :internal_user_exclusions do
      collection do
        post 'test'
        get 'stats'
      end
      member do
        post 'approve'
        post 'reject'
      end
    end
    # Removal requests are now handled through internal_user_exclusions
    # The existing internal_user_exclusions resource above handles both exclusions and removal requests
  end

  #=================================================Seller namespace for seller-specific functionality===============================#
  namespace :seller do
    post 'signup', to: 'sellers#create'
    delete 'delete_account', to: 'sellers#destroy'
    
    resources :ads do
      member do
        put 'restore'
      end
    end
    resources :orders do
      member do
        put 'update_status', to: 'orders#update_status' # Custom route for updating order status
      end
    end

    resources :shipments
    resources :categories, only: [:index, :show]
    get 'categories', to: 'categories#index'
    get 'subcategories', to: 'subcategories#index'
    resources :analytics, only: [:index]
    resources :reviews, only: [:index, :show] do
      post 'reply', on: :member
    end

    resource :profile, only: [:show, :update] do
      post 'change-password', to: 'profiles#change_password'
    end

    resources :conversations, only: [:index, :show, :create] do
      # Messages are nested under conversations
      resources :messages, only: [:index, :create]
    end

    get 'identify', to: 'sellers#identify'
    resources :notifications

    # Custom route for seller_id handling (must come before resources)
    get 'seller_tiers/:seller_id', to: 'seller_tiers#show'

    # Seller Tiers
    resources :seller_tiers, only: [:index, :show] do
      patch 'update_tier', on: :collection
    end

  end


  #==========================================Buyer namespace for buyer-specific functionality=========================================#
  namespace :buyer, defaults:{ format: :json}, path: 'buyer' do
    post 'signup', to: 'buyers#create'
    delete 'delete_account', to: 'buyers#destroy'

    resource :profile, only: [:show, :update] do
      post 'change-password', to: 'profiles#change_password'
    end

    resources :wish_lists, only: [:index, :create, :destroy] do
      member do
        post 'add_to_cart' # This route adds the ad to the cart
      end
    end

    resources :reviews
    resources :conversations, only: [:index, :show, :create] do
      # Messages are nested under conversations
      resources :messages, only: [:index, :create]
    end
    resources :categories do
      collection do
        get :analytics
      end
    end
    resources :notifications
    resources :subcategories

    resources :cart_items, only: [:index, :create, :destroy, :update] do
      collection do
        post :checkout
      end
    end

    resources :buy_for_me_order_cart_items, only: [:index, :create, :destroy, :update] do
      collection do
        post :checkout
      end
    end
    
    post 'validate_coupon', to: 'promotions#validate_coupon'

    resources :ads, only: [:index, :show] do
      collection do
        get 'search'
      end
      member do
        post 'add_to_cart'
        post 'add_to_buy_for_me_order_cart'
        get 'related', to: 'ads#related'
        get 'seller', to: 'ads#seller'
      end
      resources :reviews, only: [:create, :index] # Nested reviews under ads
    end

    resources :orders, only: [:index, :show, :create] do
      member do
        put  :update_status_to_delivered
      end
    end

    resources :buy_for_me_orders, only: [:index, :show, :create]

    get 'identify', to: 'buyers#identify'
  end


#for sales
    namespace :sales do
      resources :analytics, only: [:index]  # Dashboard data
    end


  #==========================================Rider namespace for buyer-specific functionality=========================================#
  namespace :rider do
    resources :riders
    resources :orders
    post 'signup', to: 'riders#create'
  end
  #========================================== End of Rider namespace for buyer-specific functionality=========================================#

  mount ActionCable.server => '/cable'
end
