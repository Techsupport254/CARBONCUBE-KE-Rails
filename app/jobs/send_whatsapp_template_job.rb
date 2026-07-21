class SendWhatsappTemplateJob < ApplicationJob
  queue_as :broadcast

  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  discard_on ActiveJob::DeserializationError

  def perform(user_id, template_name, language_code = 'en', components = [], user_type = 'seller')
    model_class = user_type == 'buyer' ? Buyer : Seller
    user = model_class.find_by(id: user_id)

    if user.nil?
      Rails.logger.error "[SendWhatsappTemplateJob] #{user_type.capitalize} #{user_id} not found"
      return
    end

    if user.phone_number.blank?
      Rails.logger.warn "[SendWhatsappTemplateJob] #{user_type.capitalize} #{user_id} has no phone number"
      return
    end

    result = WhatsAppCloudService.send_template(user.phone_number, template_name, language_code, components)

    if result[:success]
      Rails.logger.info "[SendWhatsappTemplateJob] Successfully sent template '#{template_name}' to #{user.phone_number}"
    else
      Rails.logger.error "[SendWhatsappTemplateJob] Failed to send template '#{template_name}' to #{user.phone_number}: #{result[:error]}"
    end
  end
end
