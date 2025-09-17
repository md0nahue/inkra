require 'sidekiq/web'

Rails.application.routes.draw do
  
  # Mount Sidekiq web UI (protect in production)
  if Rails.env.development?
    mount Sidekiq::Web => '/sidekiq'
  end
  get 'projects/index'
  get 'projects/show'
  get 'projects/new'
  get 'projects/create'
  get 'home/index'
  namespace :api do
    resource :user_preferences, only: [:show, :update]
    put 'user/interests', to: 'users#update_interests'
    # Authentication endpoints
    post 'auth/register', to: 'auth#register'
    post 'auth/login', to: 'auth#login'
    post 'auth/refresh', to: 'auth#refresh'
    post 'auth/logout', to: 'auth#logout'
    
    resources :projects, only: [:index, :show, :create, :update, :destroy] do
      collection do
        get 'recent'
      end
      member do
        patch 'outline'
        get 'transcript'
        patch 'transcript'
        post 'add_more_chapters'
        post 'complete_interview'
        get 'available_questions'
        get 'questions_with_responses'
        get 'follow_up_questions'
        get 'questions/diff', to: 'projects#questions_diff'
        post 'interview_mode', to: 'projects#interview_mode'
        post 'generate_audiogram_data', to: 'projects#generate_audiogram_data'
        post 'generate_stock_image_topics', to: 'projects#generate_stock_image_topics'
        post 'fetch_stock_images', to: 'projects#fetch_stock_images'
        
        # Export endpoints
        get 'export/preview', to: 'exports#preview'
        get 'export/pdf', to: 'exports#pdf'
        get 'export/docx', to: 'exports#docx'
        get 'export/txt', to: 'exports#txt'
        get 'export/csv', to: 'exports#csv'
        post 'export/podcast', to: 'exports#podcast'
        get 'export/podcast/status/:job_id', to: 'exports#podcast_status'
        
      end
      
      # Question-specific routes
      resources :questions, only: [] do
        member do
          post 'skip'
        end
      end
      
      resources :audio_segments, only: [] do
        collection do
          post 'upload_request'
          post 'upload_complete'
        end
        member do
          get 'playback_url'
          get 'transcription_details'
        end
      end
      
    end
    
    # Interview questions endpoints
    post 'interview_questions/generate_outline', to: 'interview_questions#generate_outline'
    post 'interview_questions/generate_section_questions', to: 'interview_questions#generate_section_questions'
    post 'interview_questions/refine_questions', to: 'interview_questions#refine_questions'
    post 'interview_questions/create_project_from_outline', to: 'interview_questions#create_project_from_outline'
    post 'interview_questions/add_questions_to_section', to: 'interview_questions#add_questions_to_section'
    
    # Voices endpoint
    get 'voices', to: 'voices#index'
    
    # Interview presets endpoints
    resources :interview_presets, param: :uuid, only: [:index, :show] do
      member do
        post 'mark_as_shown'
        post 'launch'
      end
      collection do
        get 'categories'
        get 'featured'
      end
    end
    
    # Polly voices endpoints
    resources :polly_voices, only: [:index] do
      member do
        post 'generate_demo'
      end
    end
    
    # Polly audio generation endpoints
    resources :projects, only: [] do
      member do
        post 'polly_audio/generate_all', to: 'polly_audio#generate_all'
        post 'polly_audio/generate_missing', to: 'polly_audio#generate_missing'
        put 'polly_audio/update_voice_settings', to: 'polly_audio#update_voice_settings'
        get 'polly_audio/status', to: 'polly_audio#status'
        delete 'polly_audio/cleanup_failed', to: 'polly_audio#cleanup_failed'
      end
    end
    post 'polly_audio/generate_questions', to: 'polly_audio#generate_questions'
    get 'polly_audio/voices', to: 'polly_audio#voices'
    
    
    # Transcription endpoint
    post 'transcribe_topic', to: 'transcriptions#create'
    
    # Quote extraction endpoint
    post 'extract_quotes', to: 'quote_extraction#extract'
    
    
    # Feedback endpoints
    resources :feedbacks, only: [:create, :index]
    
    # Device Logs endpoints
    resources :device_logs, only: [:index] do
      collection do
        post 'presigned_url'
      end
      member do
        post 'confirm_upload'
        get 'download_url'
      end
    end
    
    # Runware AI image generation endpoints
    post 'runware/create_icon', to: 'runware#create_icon'
    post 'runware/create_portrait', to: 'runware#create_portrait'
    post 'runware/create_tall', to: 'runware#create_tall'
    post 'runware/create_custom', to: 'runware#create_custom'
    get 'runware/status', to: 'runware#status'
    
    # User lifecycle endpoints
    post 'user_lifecycle/export_user_data', to: 'user_lifecycle#export_user_data'
    post 'user_lifecycle/delete_account', to: 'user_lifecycle#delete_account'
    get 'user_lifecycle/export_status', to: 'user_lifecycle#export_status'
    
  end
  
  # Admin routes (development/admin only)
  namespace :admin do
    # Admin routes removed - presets functionality removed
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/") - Simple health check
  root "rails/health#show"
  
  # Web interface routes
  resources :projects, only: [:index, :show, :new, :create]
  
end
