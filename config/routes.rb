
Rails.application.routes.draw do
  # SEO Redirects - Handle common URL issues
  get '/home', to: redirect('/', status: 301)
  get '/seller-', to: redirect('/become-a-seller', status: 301)
  get '/search', to: redirect('/', status: 301)
  
  # Redirect /ad/* to /ads/* (fix old ad URLs)
  get '/ad/:path', to: redirect('/ads/%{path}', status: 301), constraints: { path: /.*/ }
  
  # Redirect /seller/tiers/ (with trailing slash) to /tiers
  get '/seller/tiers/', to: redirect('/tiers', status: 301)
  
  # Redirect /seller-help to /vendor-help
  get '/seller-help', to: redirect('/vendor-help', status: 301)
  
  # Redirect /privacy-policy to /privacy
  get '/privacy-policy', to: redirect('/privacy', status: 301)
  
  # Redirect /about to /about-us
  get '/about', to: redirect('/about-us', status: 301)
  
  # Redirect /sitemap to /sitemap.xml
  get '/sitemap', to: redirect('/sitemap.xml', status: 301)

  # Redirect old location URLs that are no longer valid (sub-counties/cities to counties)
  get '/location/malindi', to: redirect('/location/kilifi', status: 301) # Malindi sub-county → Kilifi county
  get '/location/eldoret', to: redirect('/location/uasin-gishu', status: 301) # Eldoret city → Uasin Gishu county
  get '/location/thika', to: redirect('/location/kiambu', status: 301) # Thika Town → Kiambu county
  get '/location/kitale', to: redirect('/location/trans-nzoia', status: 301) # Kitale city → Trans-Nzoia county

  # Redirect old category URLs that are no longer valid
  get '/categories/phones', to: redirect('/categories/computers-phones-and-accessories', status: 301)
  get '/categories/laptops', to: redirect('/categories/computers-phones-and-accessories', status: 301)
  get '/categories/computer-parts-accessories/internal-components', to: redirect('/categories/computers-phones-and-accessories', status: 301)
  get '/categories/computer-parts-accessories/accessories', to: redirect('/categories/computers-phones-and-accessories', status: 301)
  get '/categories/computer-parts-accessories/others', to: redirect('/categories/computers-phones-and-accessories', status: 301)
  get '/categories/fuel-filters', to: redirect('/categories/filtration', status: 301)
  
  # Health check endpoints
  get '/health', to: 'health#show'
  get '/health/database', to: 'health#database'
  get '/health/redis', to: 'health#redis'
  get '/health/overall', to: 'health#overall'
  # Health check endpoints
  get '/health/websocket', to: 'health#websocket_status'
  get '/health/overall', to: 'health#overall_health'
  
  # Proxy endpoints
  get '/proxy-image', to: 'proxy#proxy_image'
  
  # Geocoding endpoints
  get '/geocoding/reverse', to: 'geocoding#reverse'
  get '/geocoding/search', to: 'geocoding#search'
  
  # Profile picture caching endpoints (both root and API scope)
  get '/cached_profile_pictures/:filename', to: 'profile_pictures#show'
  
  # Best sellers routes
  resources :best_sellers, only: [:index] do
    collection do
      get 'global'
      get 'refresh'
    end
  end

  root to: 'application#home'
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.

  # Email, username, phone, and business validation routes
  post 'email/exists', to: 'email#exists'
  post 'username/exists', to: 'email#username_exists'
  post 'phone/exists', to: 'email#phone_exists'
  post 'business_name/exists', to: 'email#business_name_exists'
  post 'business_number/exists', to: 'email#business_number_exists'
  
  # GET routes for easier frontend integration
  get 'check_phone', to: 'email#phone_exists'
  get 'check_email', to: 'email#exists'
  get 'check_username', to: 'email#username_exists'
  
  # Validation routes for frontend
  post 'validate_phone', to: 'email#phone_exists'
  post 'validate_email', to: 'email#exists'
  post 'validate_username', to: 'email#username_exists'
  
  # WhatsApp check route
  post 'whatsapp/check', to: 'whatsapp#check_number'
  get 'whatsapp/check', to: 'whatsapp#check_number'
  
  # Contact form routes
  post 'contact/submit', to: 'contact#submit'
  
  # Data deletion request routes
  post 'data_deletion/request', to: 'data_deletion#create'
  get 'data_deletion/status/:token', to: 'data_deletion#status'
  
  # Unified conversations and messages endpoints for all user types
  resources :conversations, only: [:index, :show, :create] do
    resources :messages, only: [:index, :create] do
      member do
        patch :mark_as_read
        patch :mark_as_delivered
        get :status
      end
      collection do
        post :process_pending_deliveries
        post :send_test_email
      end
    end
    member do
      post :ping_client
    end
    collection do
      get :unread_count
      get :unread_counts
      post :online_status
    end
  end

  # Alias for /messages/threads to /conversations (for frontend compatibility)
  get '/messages/threads', to: 'conversations#index'

  #========================================Public namespace for public-specific functionality==========================================#
  
  get "up" => "rails/health#show", as: :rails_health_check
  post 'auth/login', to: 'authentication#login'
  post 'auth/refresh', to: 'authentication#refresh_token'
  post 'auth/logout', to: 'authentication#logout'
  get 'auth/me', to: 'authentication#me'
  
  # Google OAuth routes
  post 'auth/google', to: 'authentication#google_oauth'
  get 'auth/google_oauth2/initiate', to: 'authentication#google_oauth_initiate' # For redirect flow with signed state
  post 'auth/complete_oauth_registration', to: 'authentication#complete_registration'
  post 'auth/complete_registration', to: 'authentication#complete_registration'
  get 'auth/google_oauth2/callback', to: 'authentication#google_oauth_callback'
  post 'auth/google_oauth2/callback', to: 'authentication#google_oauth_callback' # Handle POST requests (should be GET, but handle gracefully)
  get 'auth/google_oauth2/popup_callback', to: 'authentication#google_oauth_popup_callback'
  get 'auth/google/retrieve', to: 'authentication#retrieve_oauth_data'
  # Handle requests to /auth/google/callback (in case redirect URI is misconfigured)
  get 'auth/google/callback', to: 'authentication#google_oauth_callback'
  post 'auth/google/callback', to: 'authentication#google_oauth_callback'
  resources :banners, only: [:index]
  resources :categories, only: [:index, :show]
  resources :ads, only: [:index, :show] do
    get 'reviews', to: 'reviews#index', on: :member
  end
  
  # Sitemap generation endpoints (public)
  get 'sitemap', to: 'sitemap#index'
  get 'sitemap/ads', to: 'sitemap#ads'
  get 'sitemap/sellers', to: 'sitemap#sellers'
  
  # Issue tracking endpoints
  resources :issues, only: [:index, :show, :create] do
    member do
      post :add_comment
      post :add_attachment
    end
    collection do
      get :statistics
    end
  end
  get 'sitemap/categories', to: 'sitemap#categories'
  get 'sitemap/subcategories', to: 'sitemap#subcategories'
  get 'sitemap/stats', to: 'sitemap#stats'
  

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
  
  # STK Push payment routes
  post "payments/initiate", to: "payments#initiate_payment"
  get "payments/status/:payment_id", to: "payments#check_payment_status"
  post "payments/stk_callback", to: "payments#stk_callback"
  get "payments/history", to: "payments#payment_history"
  delete "payments/cancel/:payment_id", to: "payments#cancel_payment"
  
  # Manual payment verification routes
  get "payments/manual_instructions", to: "payments#manual_payment_instructions"
  post "payments/verify_manual", to: "payments#verify_manual_payment"
  post "payments/confirm_manual", to: "payments#confirm_manual_payment"
  
  # Routes for counties and sub_counties
  resources :counties, only: [:index] do
    get 'sub_counties', on: :member # /counties/:id/sub_counties
  end

  # Routes for age_groups
  resources :age_groups, only: [:index]

  # Routes for document_types
  resources :document_types, only: [:index]

  # Routes for password OTPs
  post '/password_resets/request_otp', to: 'password_resets#request_otp'
  post '/password_resets/verify_otp', to: 'password_resets#verify_otp'
  post '/password_resets/reset_password', to: 'password_resets#reset_password'

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
    collection do
      patch 'complete_registration', to: 'sellers#complete_registration'
    end
  end

  # Public sellers endpoint for sitemap generation
  get 'sellers', to: 'sellers#index'

  # Route for shop pages
  get 'shop/:slug', to: 'shops#show', as: :shop
  get 'shop/:slug/reviews', to: 'shops#reviews', as: :shop_reviews
  post 'shop/:slug/reviews', to: 'shops#create_review', as: :create_shop_review
  get 'shop/:slug/meta', to: 'shops#meta_tags', as: :shop_meta_tags

  # Catch-all route for missing static files (like images)
  get 'ads/*filename', to: 'application#missing_file', constraints: { filename: /.*/ }

  # Routes for document types
  resources :document_types, only: [:index]

  # Routes for internal user exclusions and removal requests
  resources :internal_user_exclusions, only: [:create] do
    collection do
      get 'check/:device_hash', to: 'internal_user_exclusions#check_status'
      get 'check_ip', to: 'internal_user_exclusions#check_ip'
      patch 'update_status/:device_hash', to: 'internal_user_exclusions#update_status'
    end
  end

  # Routes for device fingerprint persistence
  resources :device_fingerprints, only: [] do
    collection do
      post 'store', to: 'device_fingerprints#store'
      post 'recover', to: 'device_fingerprints#recover'
    end
  end


  #========================================Admin namespace for admin-specific functionality==========================================#
  namespace :admin do
    namespace :seller do
      get ':seller_id/profile', to: 'profiles#show'
      get ':seller_id/ads', to: 'ads#index'
      get ':seller_id/ads/:ad_id/reviews', to: 'reviews#index'
    end

    namespace :buyer do
      get ':buyer_id/profile', to: 'profiles#show'
    end

    resources :quarterly_targets, only: [:index] do
      collection do
        get :pending
      end
      member do
        patch :approve
        patch :reject
      end
    end
    

    namespace :rider do
      get ':rider_id/profile', to: 'profiles#show'
    end

    resources :categories
    resources :subcategories
    
    # Issue Management
    resources :issues, only: [:show, :update, :destroy] do
      member do
        post :assign
        post :add_comment
        post :add_attachment
      end
      collection do
        get :index, action: :admin_index
        get :statistics
      end
    end
    
    # Seller Communications
    resources :seller_communications, only: [] do
      collection do
        post 'send_general_update'
        post 'send_to_test_seller'
        post 'send_bulk_emails'
      end
    end
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
        put 'flag'
        put 'unflag'
        get 'analytics'
        get 'ads'
        get 'reviews'
        post :verify_document
      end
      collection do
        post 'bulk_actions'
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
      end
    end

      resources :conversations, only: [:index, :show, :create] do
        resources :messages, only: [:index, :create]
        get :unread_count, on: :collection
        get :unread_counts, on: :collection
      end

    resources :analytics
    resources :reviews
    resources :review_requests, only: [:index, :show] do
      member do
        patch :approve
        patch :reject
      end
    end
    resources :abouts
    resources :faqs
    resources :banners
    resources :promotions, except: [:new, :edit]
    resources :offers, except: [:new, :edit] do
      member do
        post :activate
        post :pause
        post :approve
      end
      collection do
        get :analytics
        post :bulk_actions
        get :templates
      end
    end
    get 'identify', to: 'admins#identify'
    resource :profile, only: [:show, :update] do
      collection do
        post 'change-password'
      end
    end
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
    
    # Google Merchant API management
    resources :google_merchant, only: [] do
      collection do
        get 'status'
        get 'test_connection'
        get 'ads'
        get 'debug_products'
        post 'sync_all'
        post 'cleanup_duplicates'
      end
      member do
        post 'sync_ad'
      end
    end
    
    # Removal requests are now handled through internal_user_exclusions
    # The existing internal_user_exclusions resource above handles both exclusions and removal requests
  end

  #=================================================Seller namespace for seller-specific functionality===============================#
  namespace :seller do
    post 'signup', to: 'sellers#create'
    delete 'delete_account', to: 'sellers#destroy'
    
    # Consolidated dashboard endpoint
    get 'dashboard', to: 'dashboard#index'
    
    resources :ads do
      member do
        put 'restore'
        get 'buyer_details', to: 'buyer_details#show'
        get 'buyer_details/summary', to: 'buyer_details#summary'
        post 'offer', to: 'ads#create_offer'
        delete 'offer', to: 'ads#remove_offer'
      end
    end


    resources :categories, only: [:index, :show]
    get 'categories', to: 'categories#index'
    
    # Seller Offers Management
    resources :offers, except: [:new, :edit] do
      member do
        post :activate
        post :pause
        post :add_ads
        delete :remove_ads
      end
      collection do
        get :offer_types
        get :templates
        get :my_ads
        get :analytics
      end
    end
    get 'subcategories', to: 'subcategories#index'
    resources :analytics, only: [:index]
    resources :reviews, only: [:index, :show] do
      post 'reply', on: :member
    end

    resource :profile, only: [:show, :update] do
      post 'change-password', to: 'profiles#change_password'
    end

    resources :review_requests, only: [:index, :create]

    resources :seller_documents

    resources :conversations, only: [:index, :show, :create] do
      # Messages are nested under conversations
      resources :messages, only: [:index, :create]
      get :unread_count, on: :collection
      get :unread_counts, on: :collection
    end

    get 'identify', to: 'sellers#identify'

    # Custom route for seller_id handling (must come before resources)
    get 'seller_tiers/:seller_id', to: 'seller_tiers#show'

    # Seller Tiers
    resources :seller_tiers, only: [:index, :show] do
      patch 'update_tier', on: :collection
    end

  end


  #==========================================Buyer namespace for buyer-specific functionality=========================================#
  # Support both /buyer and /api/buyer routes for backward compatibility
  scope '/api', defaults: { format: :json } do
    # Profile picture caching endpoints (accessible via /api/cached_profile_pictures/:filename)
    get '/cached_profile_pictures/:filename', to: 'profile_pictures#show'
    namespace :buyer, path: 'buyer' do
      post 'signup', to: 'buyers#create'
      delete 'delete_account', to: 'buyers#destroy'

      resource :profile, only: [:show, :update] do
        post 'change-password', to: 'profiles#change_password'
        post 'request-verification', to: 'profiles#request_verification'
        post 'verify-email', to: 'profiles#verify_email'
      end

      resources :wish_lists, only: [:index, :create, :destroy] do
        collection do
          get :count
        end
        member do
          post 'add_to_cart' # This route adds the ad to the cart
        end
      end

      resources :reviews
      resources :conversations, only: [:index, :show, :create] do
        # Messages are nested under conversations
        resources :messages, only: [:index, :create]
        get :unread_count, on: :collection
        get :unread_counts, on: :collection
      end
      resources :categories do
        collection do
          get :analytics
        end
      end
      resources :subcategories

      resources :cart_items, only: [:index, :create, :destroy, :update] do
        collection do
          post :checkout
        end
      end
      
      post 'validate_coupon', to: 'promotions#validate_coupon'
      
      # Offers routes
      resources :offers, only: [:index, :show] do
        member do
          post :track_click
        end
        collection do
          get :active_offers
          get :featured_offers
          get :upcoming_offers
          get :by_type
          get :calendar
          get :search
          get :black_friday
          get :cyber_monday
          get :flash_sales
          get :clearance
          get :seasonal
          get :holiday
        end
      end

      resources :ads, only: [:index, :show] do
        collection do
          get 'search'
          get 'load_more_subcategory'
          get 'recommendations', to: 'ads#recommendations'
        end
        member do
          post 'add_to_cart'
          get 'related', to: 'ads#related'
          get 'seller', to: 'ads#seller'
          get 'alternatives', to: 'ads#alternatives'
        end
        resources :reviews, only: [:create, :index] # Nested reviews under ads
      end

      get 'identify', to: 'buyers#identify'
    end
  end
  
  # Original routes without /api prefix for backward compatibility
  namespace :buyer, defaults:{ format: :json}, path: 'buyer' do
    post 'signup', to: 'buyers#create'
    delete 'delete_account', to: 'buyers#destroy'

    resource :profile, only: [:show, :update] do
      post 'change-password', to: 'profiles#change_password'
      post 'request-verification', to: 'profiles#request_verification'
      post 'verify-email', to: 'profiles#verify_email'
    end

    resources :wish_lists, only: [:index, :create, :destroy] do
      collection do
        get :count
      end
      member do
        post 'add_to_cart' # This route adds the ad to the cart
      end
    end

    resources :reviews
    resources :conversations, only: [:index, :show, :create] do
      # Messages are nested under conversations
      resources :messages, only: [:index, :create]
      get :unread_count, on: :collection
      get :unread_counts, on: :collection
    end
    resources :categories do
      collection do
        get :analytics
      end
    end
    resources :subcategories

    resources :cart_items, only: [:index, :create, :destroy, :update] do
      collection do
        post :checkout
      end
    end
    
    post 'validate_coupon', to: 'promotions#validate_coupon'
    
    # Offers routes
    resources :offers, only: [:index, :show] do
      member do
        post :track_click
      end
      collection do
        get :active_offers
        get :featured_offers
        get :upcoming_offers
        get :by_type
        get :calendar
        get :search
        get :black_friday
        get :cyber_monday
        get :flash_sales
        get :clearance
        get :seasonal
        get :holiday
      end
    end

    resources :ads, only: [:index, :show] do
      collection do
        get 'search'
        get 'load_more_subcategory'
        get 'recommendations', to: 'ads#recommendations'
      end
      member do
        post 'add_to_cart'
        get 'related', to: 'ads#related'
        get 'seller', to: 'ads#seller'
        get 'alternatives', to: 'ads#alternatives'
      end
      resources :reviews, only: [:create, :index] # Nested reviews under ads
    end

    get 'identify', to: 'buyers#identify'
  end


#for sales
    namespace :sales do
      resources :seller_rankings, only: [:index] do
        collection do
          get :by_metric
        end
      end
      resource :profile, only: [:show, :update] do
        collection do
          post 'change-password'
        end
      end
      resources :analytics, only: [:index] do
        collection do
          get :recent_users
          get :devices
          get :sources
          get :categories
        end
      end
      resources :click_events, only: [] do
        collection do
          get :analytics
          get :best_ads
        end
      end
      resources :reviews, only: [:index]
      resources :wishlists, only: [:index], path: 'wishlists', controller: 'wish_lists'
      resources :quarterly_targets, only: [:index, :create, :update, :destroy] do
        collection do
          get :current
        end
      end
      resources :conversations, only: [:index, :show, :create] do
        resources :messages, only: [:index, :create]
        get :unread_count, on: :collection
        get :unread_counts, on: :collection
      end
    end




  mount ActionCable.server => '/cable'

    post '/visitor/track', to: 'visitor_analytics#track_visitor'
    get '/visitor/analytics', to: 'visitor_analytics#analytics'
    get '/visitor/list', to: 'visitor_analytics#visitors_list'
    get '/visitor/:visitor_id', to: 'visitor_analytics#visitor_details'
    get '/visitor/:visitor_id/click_events', to: 'visitor_analytics#visitor_click_events'
end
