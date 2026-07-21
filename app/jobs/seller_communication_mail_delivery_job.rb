class SellerCommunicationMailDeliveryJob < ApplicationJob
  queue_as :default

  def perform(mailer_class, mailer_method, delivery_method, args)
    seller = extract_seller_from_args(args)
    
    if seller
      begin
        mailer_instance = mailer_class.constantize.with(seller: seller)
        mailer_instance.public_send(mailer_method).public_send(delivery_method)
      rescue => e
        Rails.logger.error "Email delivery failed: #{e.message}"
        raise e
      end
    else
      Rails.logger.error "No seller found in job arguments"
      raise "No seller found in job arguments"
    end
  end

  private

  def extract_seller_from_args(args)
    if args.is_a?(Hash) && args.key?(:args) && args[:args].is_a?(Array) && args[:args].first.is_a?(Seller)
      return args[:args].first
    end
    
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
    
    return args if args.is_a?(Seller)
    
    return args.first if args.is_a?(Array) && args.first.is_a?(Seller)
    
    if args.is_a?(Hash) && args.key?(:args) && args[:args].is_a?(Seller)
      return args[:args]
    end
    
    nil
  end
end
