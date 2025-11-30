class Admin::UsersController < ApplicationController
  before_action :authenticate_admin
  
  # GET /admin/users
  def index
    role = params[:role]&.downcase
    query = params[:query]&.strip
    
    users = case role
            when 'admin'
              Admin.all
            when 'sales'
              SalesUser.all
            when 'marketing'
              MarketingUser.all
            else
              # Return all staff users (admin, sales, marketing)
              all_users = []
              Admin.all.each { |u| all_users << { id: u.id, email: u.email, fullname: u.fullname, role: 'admin', created_at: u.created_at } }
              SalesUser.all.each { |u| all_users << { id: u.id, email: u.email, fullname: u.fullname, role: 'sales', created_at: u.created_at } }
              MarketingUser.all.each { |u| all_users << { id: u.id, email: u.email, fullname: u.fullname, role: 'marketing', created_at: u.created_at } }
              all_users.sort_by { |u| u[:created_at] }.reverse
            end
    
    # Search functionality
    if query.present?
      if role.present?
        users = case role
                when 'admin'
                  Admin.where("email ILIKE :search OR fullname ILIKE :search OR username ILIKE :search", search: "%#{query}%")
                when 'sales'
                  SalesUser.where("email ILIKE :search OR fullname ILIKE :search", search: "%#{query}%")
                when 'marketing'
                  MarketingUser.where("email ILIKE :search OR fullname ILIKE :search", search: "%#{query}%")
                end
      else
        # Search across all roles
        admin_results = Admin.where("email ILIKE :search OR fullname ILIKE :search OR username ILIKE :search", search: "%#{query}%")
        sales_results = SalesUser.where("email ILIKE :search OR fullname ILIKE :search", search: "%#{query}%")
        marketing_results = MarketingUser.where("email ILIKE :search OR fullname ILIKE :search", search: "%#{query}%")
        
        all_users = []
        admin_results.each { |u| all_users << { id: u.id, email: u.email, fullname: u.fullname, role: 'admin', created_at: u.created_at, username: u.username } }
        sales_results.each { |u| all_users << { id: u.id, email: u.email, fullname: u.fullname, role: 'sales', created_at: u.created_at } }
        marketing_results.each { |u| all_users << { id: u.id, email: u.email, fullname: u.fullname, role: 'marketing', created_at: u.created_at } }
        users = all_users.sort_by { |u| u[:created_at] }.reverse
      end
    end
    
    # Pagination
    page = params[:page]&.to_i || 1
    per_page = params[:per_page]&.to_i || 20
    page = 1 if page < 1
    per_page = [per_page, 100].min
    per_page = 20 if per_page < 1
    
    if users.is_a?(Array)
      total_count = users.length
      offset = (page - 1) * per_page
      paginated_users = users[offset, per_page] || []
    else
      total_count = users.count
      offset = (page - 1) * per_page
      paginated_users = users.limit(per_page).offset(offset)
    end
    
    # Format response
    formatted_users = if paginated_users.is_a?(Array)
      paginated_users
    else
      paginated_users.map do |user|
        {
          id: user.id,
          email: user.email,
          fullname: user.fullname || user.email.split('@').first,
          role: case user.class.name
                when 'Admin' then 'admin'
                when 'SalesUser' then 'sales'
                when 'MarketingUser' then 'marketing'
                end,
          username: user.respond_to?(:username) ? user.username : nil,
          created_at: user.created_at,
          updated_at: user.updated_at
        }
      end
    end
    
    render json: {
      users: formatted_users,
      pagination: {
        page: page,
        per_page: per_page,
        total: total_count,
        total_pages: (total_count.to_f / per_page).ceil
      }
    }, status: :ok
  end
  
  # POST /admin/users
  def create
    role = params[:role]&.downcase
    email = params[:email]&.downcase&.strip
    fullname = params[:fullname]&.strip
    password = params[:password]
    username = params[:username]&.strip if params[:username].present?
    
    # Validate required fields
    if role.blank? || !['admin', 'sales', 'marketing'].include?(role)
      return render json: { error: 'Invalid role. Must be admin, sales, or marketing' }, status: :bad_request
    end
    
    if email.blank?
      return render json: { error: 'Email is required' }, status: :bad_request
    end
    
    if password.blank?
      return render json: { error: 'Password is required' }, status: :bad_request
    end
    
    # Check if email already exists
    existing_user = Admin.find_by(email: email) ||
                    SalesUser.find_by(email: email) ||
                    MarketingUser.find_by(email: email) ||
                    Buyer.find_by(email: email) ||
                    Seller.find_by(email: email)
    
    if existing_user
      return render json: { error: 'Email is already registered' }, status: :unprocessable_entity
    end
    
    # Check username uniqueness for admin
    if role == 'admin' && username.present?
      if Admin.exists?(username: username)
        return render json: { error: 'Username is already taken' }, status: :unprocessable_entity
      end
    end
    
    # Create user based on role
    begin
      user = case role
             when 'admin'
               Admin.create!(
                 email: email,
                 fullname: fullname || email.split('@').first,
                 username: username || email.split('@').first.gsub(/[^a-zA-Z0-9_]/, ''),
                 password: password,
                 password_confirmation: password
               )
             when 'sales'
               SalesUser.create!(
                 email: email,
                 fullname: fullname || email.split('@').first,
                 password: password,
                 password_confirmation: password
               )
             when 'marketing'
               MarketingUser.create!(
                 email: email,
                 fullname: fullname || email.split('@').first,
                 password: password,
                 password_confirmation: password
               )
             end
      
      render json: {
        success: true,
        message: "#{role.capitalize} user created successfully",
        user: {
          id: user.id,
          email: user.email,
          fullname: user.fullname,
          role: role,
          username: user.respond_to?(:username) ? user.username : nil,
          created_at: user.created_at
        }
      }, status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: {
        error: 'Validation failed',
        errors: e.record.errors.full_messages
      }, status: :unprocessable_entity
    rescue => e
      Rails.logger.error "Error creating user: #{e.message}"
      render json: { error: 'Failed to create user' }, status: :internal_server_error
    end
  end
  
  # PUT /admin/users/:id
  def update
    role = params[:role]&.downcase
    
    unless ['admin', 'sales', 'marketing'].include?(role)
      return render json: { error: 'Invalid role' }, status: :bad_request
    end
    
    user = case role
           when 'admin'
             Admin.find_by(id: params[:id])
           when 'sales'
             SalesUser.find_by(id: params[:id])
           when 'marketing'
             MarketingUser.find_by(id: params[:id])
           end
    
    unless user
      return render json: { error: 'User not found' }, status: :not_found
    end
    
    # Update attributes
    update_params = {}
    
    if params[:email].present?
      # Check if email is already taken by another user
      existing_user = Admin.find_by(email: params[:email]) ||
                      SalesUser.find_by(email: params[:email]) ||
                      MarketingUser.find_by(email: params[:email]) ||
                      Buyer.find_by(email: params[:email]) ||
                      Seller.find_by(email: params[:email])
      
      if existing_user && existing_user.id != user.id
        return render json: { error: 'Email is already registered' }, status: :unprocessable_entity
      end
      update_params[:email] = params[:email].downcase.strip
    end
    
    if params[:fullname].present?
      update_params[:fullname] = params[:fullname].strip
    end
    
    if params[:password].present?
      update_params[:password] = params[:password]
      update_params[:password_confirmation] = params[:password]
    end
    
    # Admin-specific: username
    if role == 'admin' && params[:username].present?
      # Check username uniqueness
      existing_admin = Admin.find_by(username: params[:username])
      if existing_admin && existing_admin.id != user.id
        return render json: { error: 'Username is already taken' }, status: :unprocessable_entity
      end
      update_params[:username] = params[:username].strip
    end
    
    begin
      if user.update(update_params)
        render json: {
          success: true,
          message: 'User updated successfully',
          user: {
            id: user.id,
            email: user.email,
            fullname: user.fullname,
            role: role,
            username: user.respond_to?(:username) ? user.username : nil,
            updated_at: user.updated_at
          }
        }, status: :ok
      else
        render json: {
          error: 'Validation failed',
          errors: user.errors.full_messages
        }, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error "Error updating user: #{e.message}"
      render json: { error: 'Failed to update user' }, status: :internal_server_error
    end
  end
  
  # DELETE /admin/users/:id
  def destroy
    role = params[:role]&.downcase
    
    unless ['admin', 'sales', 'marketing'].include?(role)
      return render json: { error: 'Invalid role' }, status: :bad_request
    end
    
    user = case role
           when 'admin'
             Admin.find_by(id: params[:id])
           when 'sales'
             SalesUser.find_by(id: params[:id])
           when 'marketing'
             MarketingUser.find_by(id: params[:id])
           end
    
    unless user
      return render json: { error: 'User not found' }, status: :not_found
    end
    
    # Prevent deleting yourself
    if user.id == @current_user.id && role == 'admin'
      return render json: { error: 'Cannot delete your own account' }, status: :unprocessable_entity
    end
    
    if user.destroy
      render json: { success: true, message: 'User deleted successfully' }, status: :ok
    else
      render json: { error: 'Failed to delete user' }, status: :internal_server_error
    end
  end

  private

  def authenticate_admin
    @current_user = AdminAuthorizeApiRequest.new(request.headers).result
    unless @current_user && @current_user.is_a?(Admin)
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end
end

