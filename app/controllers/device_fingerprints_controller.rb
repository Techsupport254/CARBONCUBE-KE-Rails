class DeviceFingerprintsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:store, :recover]
  
  # POST /device_fingerprints/store
  def store
    device_id = params[:device_id]
    hardware_fingerprint = params[:hardware_fingerprint]
    user_agent = params[:user_agent]
    timestamp = params[:timestamp]
    
    if device_id.blank? || hardware_fingerprint.blank?
      render json: { error: 'Missing required parameters' }, status: :bad_request
      return
    end
    
    begin
      # Store or update the device fingerprint
      device_fingerprint = DeviceFingerprint.find_or_initialize_by(device_id: device_id)
      device_fingerprint.assign_attributes(
        hardware_fingerprint: hardware_fingerprint,
        user_agent: user_agent,
        last_seen: timestamp ? Time.at(timestamp / 1000) : nil,
        updated_at: Time.current
      )
      
      if device_fingerprint.save
        render json: { 
          message: 'Device fingerprint stored successfully',
          device_id: device_id 
        }, status: :ok
      else
        render json: { 
          errors: device_fingerprint.errors.full_messages 
        }, status: :unprocessable_entity
      end
    rescue => e
      render json: { error: 'Failed to store device fingerprint' }, status: :internal_server_error
    end
  end
  
  # POST /device_fingerprints/recover
  def recover
    existing_device_id = params[:existing_device_id]
    hardware_fingerprint = params[:hardware_fingerprint]
    user_agent = params[:user_agent]
    
    if hardware_fingerprint.blank?
      render json: { error: 'Missing hardware fingerprint' }, status: :bad_request
      return
    end
    
    begin
      # First, try to find by existing device ID if provided
      if existing_device_id.present?
        device_fingerprint = DeviceFingerprint.find_by(device_id: existing_device_id)
        if device_fingerprint
          # Update the hardware fingerprint and return the device ID
          device_fingerprint.update!(
            hardware_fingerprint: hardware_fingerprint,
            user_agent: user_agent,
            last_seen: Time.current
          )
          render json: { 
            device_id: device_fingerprint.device_id,
            recovered: true 
          }, status: :ok
          return
        end
      end
      
      # Try to find by hardware fingerprint match (fuzzy matching)
      # Look for devices with similar hardware characteristics
      matching_devices = DeviceFingerprint.where(
        "hardware_fingerprint LIKE ? OR hardware_fingerprint LIKE ?",
        "%#{extract_key_characteristics(hardware_fingerprint)}%",
        "%#{extract_screen_resolution(hardware_fingerprint)}%"
      ).order(last_seen: :desc).limit(5)
      
      if matching_devices.any?
        # Use the most recent match
        best_match = matching_devices.first
        best_match.update!(
          hardware_fingerprint: hardware_fingerprint,
          user_agent: user_agent,
          last_seen: Time.current
        )
        render json: { 
          device_id: best_match.device_id,
          recovered: true,
          confidence: calculate_match_confidence(hardware_fingerprint, best_match.hardware_fingerprint)
        }, status: :ok
      else
        render json: { 
          device_id: nil,
          recovered: false,
          message: 'No matching device found' 
        }, status: :ok
      end
    rescue => e
      render json: { error: 'Failed to recover device fingerprint' }, status: :internal_server_error
    end
  end
  
  private
  
  def extract_key_characteristics(fingerprint_json)
    begin
      fingerprint = JSON.parse(fingerprint_json)
      # Extract key characteristics for matching
      key_parts = [
        fingerprint['screenWidth'],
        fingerprint['screenHeight'],
        fingerprint['hardwareConcurrency'],
        fingerprint['platform']
      ].compact.join('_')
      key_parts
    rescue
      ''
    end
  end
  
  def extract_screen_resolution(fingerprint_json)
    begin
      fingerprint = JSON.parse(fingerprint_json)
      "#{fingerprint['screenWidth']}_#{fingerprint['screenHeight']}"
    rescue
      ''
    end
  end
  
  def calculate_match_confidence(current_fingerprint, stored_fingerprint)
    begin
      current = JSON.parse(current_fingerprint)
      stored = JSON.parse(stored_fingerprint)
      
      matches = 0
      total_checks = 0
      
      # Compare key characteristics
      ['screenWidth', 'screenHeight', 'hardwareConcurrency', 'platform', 'language', 'timezone'].each do |key|
        total_checks += 1
        matches += 1 if current[key] == stored[key]
      end
      
      # Compare canvas fingerprint (more weight)
      if current['canvasFingerprint'] && stored['canvasFingerprint']
        total_checks += 2
        matches += 2 if current['canvasFingerprint'] == stored['canvasFingerprint']
      end
      
      return (matches.to_f / total_checks * 100).round(2)
    rescue
      0
    end
  end
end
