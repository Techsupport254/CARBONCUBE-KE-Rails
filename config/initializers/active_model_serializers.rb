# Configure ActiveModel Serializers to reduce logging
if Rails.env.development?
  # Disable ActiveModel Serializer logging in development
  ActiveModelSerializers.logger = Logger.new(nil)
  
  # Reduce the verbosity of serializer logging
  ActiveModelSerializers.config.adapter = :attributes
end
