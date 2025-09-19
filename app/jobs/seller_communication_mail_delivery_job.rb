class SellerCommunicationMailDeliveryJob < ApplicationJob
  queue_as :default

  def perform(mailer_class, mailer_method, delivery_method, args)
    # Log to both Rails logger and stdout for Sidekiq visibility
    log_message = "=== CUSTOM MAILER JOB START ==="
    Rails.logger.info log_message
    puts log_message
    
    log_message = "Mailer: #{mailer_class} | Method: #{mailer_method} | Delivery: #{delivery_method}"
    Rails.logger.info log_message
    puts log_message
    
    log_message = "Args: #{args.inspect}"
    Rails.logger.info log_message
    puts log_message
    
    # Extract seller from various argument formats
    seller = extract_seller_from_args(args)
    
    if seller
      log_message = "📧 Sending email to: #{seller.email} (#{seller.fullname})"
      Rails.logger.info log_message
      puts log_message
      
      begin
        # Call the mailer with seller parameter
        mailer_instance = mailer_class.constantize.with(seller: seller)
        mailer_instance.public_send(mailer_method).public_send(delivery_method)
        
        log_message = "✅ Email delivered successfully!"
        Rails.logger.info log_message
        puts log_message
        
      rescue => e
        log_message = "❌ Email delivery failed: #{e.message}"
        Rails.logger.error log_message
        puts log_message
        raise e
      end
    else
      log_message = "❌ No seller found in arguments"
      Rails.logger.error log_message
      puts log_message
      raise "No seller found in job arguments"
    end
    
    log_message = "=== CUSTOM MAILER JOB END ==="
    Rails.logger.info log_message
    puts log_message
  end

  private

  def extract_seller_from_args(args)
    # Handle different argument formats
    
    # Format 1: args[:args] contains array with Seller object
    if args.is_a?(Hash) && args.key?(:args) && args[:args].is_a?(Array) && args[:args].first.is_a?(Seller)
      return args[:args].first
    end
    
    # Format 2: args[:params][:seller] contains GlobalID that needs to be resolved
    if args.is_a?(Hash) && args.key?(:params) && args[:params].is_a?(Hash) && args[:params].key?(:seller)
      seller_param = args[:params][:seller]
      if seller_param.is_a?(Hash) && seller_param.key?(:_aj_globalid)
        begin
          return GlobalID::Locator.locate(seller_param[:_aj_globalid])
        rescue => e
          Rails.logger.error "Failed to locate seller from GlobalID: #{e.message}"
          return nil
        end
      elsif seller_param.is_a?(Seller)
        return seller_param
      end
    end
    
    # Format 3: Direct Seller object
    if args.is_a?(Seller)
      return args
    end
    
    # Format 4: Array with Seller object
    if args.is_a?(Array) && args.first.is_a?(Seller)
      return args.first
    end
    
    # Format 5: Hash with args key containing Seller
    if args.is_a?(Hash) && args.key?(:args) && args[:args].is_a?(Seller)
      return args[:args]
    end
    
    return nil
  end
end
