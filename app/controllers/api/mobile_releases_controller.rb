module Api
  class MobileReleasesController < ApplicationController
    skip_before_action :verify_authenticity_token, only: [:create]
    
    # GET /api/mobile_releases/latest
    def latest
      @releases = MobileRelease.all_latest_by_abi
      
      if @releases.any?
        render json: {
          version: @releases.first.version_name,
          apks: @releases.map { |r| 
            {
              abi: r.abi,
              version_code: r.version_code,
              download_url: r.download_url,
              is_stable: r.is_stable,
              created_at: r.created_at
            }
          }
        }
      else
        render json: { version: nil, apks: [] }
      end
    end

    # POST /api/mobile_releases
    def create
      # Basic secret check for the deployment script
      auth_token = request.headers['X-Release-Token']
      expected_token = ENV['MOBILE_RELEASE_TOKEN'] || 'temporary-secret-token'
      
      if auth_token != expected_token
        return render json: { error: 'Unauthorized' }, status: :unauthorized
      end

      @release = MobileRelease.new(mobile_release_params)
      
      if @release.save
        render json: @release, status: :created
      else
        render json: @release.errors, status: :unprocessable_entity
      end
    end

    private

    def mobile_release_params
      params.require(:mobile_release).permit(:version_name, :version_code, :abi, :download_url, :is_stable, :active, :fingerprint)
    end
  end
end
