# app/controllers/sales/online_controller.rb
class Sales::OnlineController < ApplicationController
  before_action :authenticate_sales_user
  before_action :ensure_employed_or_manager

  def index
    all_user_keys = RedisConnection.keys('online_user_*')
    all_guest_keys = RedisConnection.keys('online_guest_*')

    user_keys = all_user_keys.reject { |k| k.to_s.match?(/:(?:page|location|referrer)\z/) }
    guest_keys = all_guest_keys.reject { |k| k.to_s.match?(/:(?:page|location|referrer)\z/) }

    parsed_users = user_keys.filter_map do |key|
      match = key.to_s.match(/\Aonline_user_([^_]+)_(.+)\z/)
      next unless match

      { type: match[1], id: match[2], key: key }
    end

    parsed_guests = guest_keys.filter_map do |key|
      match = key.to_s.match(/\Aonline_guest_(.+)\z/)
      next unless match

      { type: 'guest', id: match[1], key: key }
    end

    parsed = parsed_users + parsed_guests

    if parsed.empty?
      render json: { online_users: {}, total: 0 }
      return
    end

    main_keys = parsed.map { |p| p[:key] }
    page_keys = main_keys.map { |k| "#{k}:page" }

    values = RedisConnection.mget(main_keys)
    online_at_by_key = parsed.each_with_object({}).with_index do |(item, hash), index|
      hash[item[:key]] = values[index]
    end

    page_values = RedisConnection.mget(page_keys)
    page_by_key = main_keys.each_with_object({}).with_index do |(key, hash), index|
      hash[key] = page_values[index]
    end

    referrer_keys = main_keys.map { |k| "#{k}:referrer" }
    referrer_values = RedisConnection.mget(referrer_keys)
    referrer_by_key = main_keys.each_with_object({}).with_index do |(key, hash), index|
      hash[key] = referrer_values[index]
    end

    location_keys = main_keys.map { |k| "#{k}:location" }
    location_values = RedisConnection.mget(location_keys)
    location_by_key = main_keys.each_with_object({}).with_index do |(key, hash), index|
      hash[key] = location_values[index]
    end

    grouped = parsed.group_by { |p| p[:type] }
    online_users = {}
    total = 0

    grouped.each do |user_type, items|
      if user_type == 'guest'
        users = items.filter_map do |item|
          online_at_value = online_at_by_key[item[:key]]
          online_at = online_at_value ? Time.at(online_at_value.to_i).iso8601 : nil
          {
            id: item[:id],
            name: 'Guest',
            email: nil,
            phone_number: nil,
            profile_picture: nil,
            document_verified: nil,
            enterprise_name: nil,
            username: nil,
            fullname: 'Guest',
            type: 'guest',
            online_at: online_at,
            current_page: page_by_key[item[:key]],
            referrer: referrer_by_key[item[:key]],
            location: location_by_key[item[:key]]
          }
        end
      else
        ids = items.map { |item| item[:id] }
        records = records_for_type(user_type, ids)
        record_by_id = records.index_by { |r| r.id.to_s }

        users = items.filter_map do |item|
          record = record_by_id[item[:id]]
          next unless record

          online_at_value = online_at_by_key[item[:key]]
          online_at = online_at_value ? Time.at(online_at_value.to_i).iso8601 : nil
          {
            id: item[:id],
            name: display_name_for(record, user_type),
            email: record.attributes['email'],
            phone_number: record.attributes['phone_number'],
            profile_picture: record.attributes['profile_picture'],
            document_verified: record.attributes['document_verified'],
            enterprise_name: record.attributes['enterprise_name'],
            username: record.attributes['username'],
            fullname: record.attributes['fullname'],
            type: user_type,
            online_at: online_at,
            current_page: page_by_key[item[:key]],
            referrer: referrer_by_key[item[:key]],
            location: location_by_key[item[:key]]
          }
        end
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

  def ensure_employed_or_manager
    return if @current_sales_user&.is_manager || @current_sales_user&.compensation_type == 'employed'

    render json: { error: 'Online user analytics are restricted to employed sales staff and managers' }, status: :forbidden
  end

  def records_for_type(user_type, ids)
    case user_type
    when 'buyer'
      Buyer.where(id: ids).select(:id, :fullname, :username, :email, :phone_number, :profile_picture)
    when 'seller'
      Seller.where(id: ids).select(:id, :fullname, :username, :enterprise_name, :email, :phone_number, :profile_picture, :document_verified)
    when 'admin'
      Admin.where(id: ids).select(:id, :fullname, :username, :email, :phone_number, :profile_picture)
    when 'sales'
      SalesUser.where(id: ids).select(:id, :fullname, :email, :phone_number, :profile_picture)
    when 'marketing'
      MarketingUser.where(id: ids).select(:id, :fullname, :email, :phone_number, :profile_picture)
    else
      []
    end
  end

  def display_name_for(record, user_type)
    case user_type
    when 'buyer'
      record.attributes['fullname'].presence || record.attributes['username'].presence || record.attributes['email'] || 'Buyer'
    when 'seller'
      record.attributes['enterprise_name'].presence || record.attributes['fullname'].presence || record.attributes['username'].presence || 'Seller'
    when 'admin'
      record.attributes['username'].presence || record.attributes['email'] || 'Admin'
    when 'sales', 'marketing'
      record.attributes['fullname'].presence || record.attributes['email'] || user_type.capitalize
    else
      record.to_s
    end
  end
end
