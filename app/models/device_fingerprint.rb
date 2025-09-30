class DeviceFingerprint < ApplicationRecord
  validates :device_id, presence: true, uniqueness: true
  validates :hardware_fingerprint, presence: true
  
  # Index for faster lookups
  scope :recent, -> { order(last_seen: :desc) }
  scope :by_device_id, ->(device_id) { where(device_id: device_id) }
  
  # Clean up old fingerprints (older than 1 year)
  def self.cleanup_old_fingerprints
    where('last_seen < ?', 1.year.ago).delete_all
  end
  
  # Find potential matches based on hardware characteristics
  def self.find_potential_matches(hardware_fingerprint)
    begin
      fingerprint_data = JSON.parse(hardware_fingerprint)
      
      # Build query based on key characteristics
      query = all
      
      if fingerprint_data['screenWidth'] && fingerprint_data['screenHeight']
        query = query.where(
          "hardware_fingerprint LIKE ?", 
          "%\"screenWidth\":#{fingerprint_data['screenWidth']}%"
        ).where(
          "hardware_fingerprint LIKE ?", 
          "%\"screenHeight\":#{fingerprint_data['screenHeight']}%"
        )
      end
      
      if fingerprint_data['hardwareConcurrency']
        query = query.where(
          "hardware_fingerprint LIKE ?", 
          "%\"hardwareConcurrency\":#{fingerprint_data['hardwareConcurrency']}%"
        )
      end
      
      if fingerprint_data['platform']
        query = query.where(
          "hardware_fingerprint LIKE ?", 
          "%\"platform\":\"#{fingerprint_data['platform']}\"%"
        )
      end
      
      query.recent.limit(10)
    rescue JSON::ParserError
      none
    end
  end
  
  # Calculate similarity score between two fingerprints
  def similarity_score(other_fingerprint)
    begin
      current = JSON.parse(hardware_fingerprint)
      other = JSON.parse(other_fingerprint)
      
      matches = 0
      total_checks = 0
      
      # Compare key characteristics with different weights
      characteristics = {
        'screenWidth' => 2,
        'screenHeight' => 2,
        'hardwareConcurrency' => 3,
        'platform' => 1,
        'language' => 1,
        'timezone' => 1,
        'devicePixelRatio' => 1,
        'maxTouchPoints' => 1
      }
      
      characteristics.each do |key, weight|
        total_checks += weight
        matches += weight if current[key] == other[key]
      end
      
      # Canvas fingerprint gets extra weight
      if current['canvasFingerprint'] && other['canvasFingerprint']
        total_checks += 5
        matches += 5 if current['canvasFingerprint'] == other['canvasFingerprint']
      end
      
      return (matches.to_f / total_checks * 100).round(2)
    rescue JSON::ParserError
      0
    end
  end
  
  # Update last seen timestamp
  def touch_last_seen
    update_column(:last_seen, Time.current)
  end
end
