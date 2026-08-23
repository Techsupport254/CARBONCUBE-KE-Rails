# app/controllers/sales/online_controller.rb
class Sales::OnlineController < ApplicationController
  before_action :authenticate_sales_user

  def index
    keys = RedisConnection.keys('online_user_*')
    parsed = keys.filter_map do |key|
      match = key.to_s.match(/\Aonline_user_([^_]+)_(.+)\z/)
      next unless match

      { type: match[1], id: match[2], key: key }
    end

    if parsed.empty?
      render json: { online_users: {}, total: 0 }
      return
    end

    values = RedisConnection.mget(parsed.map { |p| p[:key] })
    online_at_by_key = parsed.each_with_object({}).with_index do |(item, hash), index|
      hash[item[:key]] = values[index]
    end

    grouped = parsed.group_by { |p| p[:type] }
    online_users = {}
    total = 0

    grouped.each do |user_type, items|
      ids = items.map { |item| item[:id].to_i }
      records = records_for_type(user_type, ids)
      record_by_id = records.index_by(&:id)

      users = items.filter_map do |item|
        record = record_by_id[item[:id].to_i]
        next unless record

        online_at_value = online_at_by_key[item[:key]]
        online_at = online_at_value ? Time.at(online_at_value.to_i).iso8601 : nil
        {
          id: item[:id],
          name: display_name_for(record, user_type),
          email: record.email,
          phone_number: record.respond_to?(:phone_number) ? record.phone_number : nil,
          profile_picture: record.respond_to?(:profile_picture) ? record.profile_picture : nil,
          document_verified: record.respond_to?(:document_verified) ? record.document_verified : nil,
          enterprise_name: record.respond_to?(:enterprise_name) ? record.enterprise_name : nil,
          username: record.respond_to?(:username) ? record.username : nil,
          fullname: record.respond_to?(:fullname) ? record.fullname : nil,
          type: user_type,
          online_at: online_at
        }
      end

      online_users[user_type] = users
      total += users.length
    end

    render json: { online_users: online_users, total: total }
  rescue StandardError => e
    Rails.logger.error "Error fetching online users: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { online_users: {}, total: 0 }
  end

  private

  def authenticate_sales_user
    @current_sales_user = SalesAuthorizeApiRequest.new(request.headers).result
    return if @current_sales_user

    render json: { error: 'Not Authorized' }, status: :unauthorized
  end

  def records_for_type(user_type, ids)
    case user_type
    when 'buyer'
      Buyer.where(id: ids).select(:id, :fullname, :username, :email, :phone_number, :profile_picture)
    when 'seller'
      Seller.where(id: ids).select(:id, :fullname, :username, :enterprise_name, :email, :phone_number, :profile_picture, :document_verified)
    when 'admin'
      Admin.where(id: ids).select(:id, :username, :email, :profile_picture)
    when 'sales'
      SalesUser.where(id: ids).select(:id, :fullname, :username, :email, :phone_number, :profile_picture)
    when 'marketing'
      MarketingUser.where(id: ids).select(:id, :fullname, :username, :email, :phone_number, :profile_picture)
    else
      []
    end
  end

  def display_name_for(record, user_type)
    case user_type
    when 'buyer'
      record.fullname.presence || record.username.presence || record.email || 'Buyer'
    when 'seller'
      record.enterprise_name.presence || record.fullname.presence || record.username.presence || 'Seller'
    when 'admin'
      record.username.presence || record.email || 'Admin'
    when 'sales', 'marketing'
      record.fullname.presence || record.username.presence || record.email || user_type.capitalize
    else
      record.to_s
    end
  end
end
