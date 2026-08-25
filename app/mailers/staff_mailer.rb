class StaffMailer < ApplicationMailer
  default from: "Carbon Cube Kenya <#{ENV['BREVO_EMAIL']}>"

  # Notify a staff user that their account was created by an admin.
  # Never sends the password in plaintext.
  #
  # @param user [Admin, SalesUser, MarketingUser] the newly created staff user
  # @param actor [Admin, nil] the admin who performed the action
  def account_created(user, actor: nil)
    @user = user
    @actor = actor
    @role = user.class.name.downcase
    @name = user.fullname.presence || user.username.presence || user.email.to_s.split('@').first
    @dashboard_url = dashboard_url_for(user)
    @login_url = UtmUrlHelper.append_utm(
      'https://carboncube-ke.com/login',
      source: 'email',
      medium: 'staff_account',
      campaign: 'created',
      content: 'login'
    )
    @support_email = ENV['BREVO_EMAIL'] || 'support@carboncube.co.ke'
    @support_phone = '+254 712 990 524'
    @timestamp = Time.current.strftime('%B %d, %Y at %I:%M %p')

    mail(
      to: user.email,
      bcc: ENV['BREVO_EMAIL'],
      subject: "Your Carbon Cube Kenya #{@role.capitalize} account is ready",
      react: {
        name: @name,
        role: @role,
        login_url: @login_url,
        dashboard_url: @dashboard_url,
        support_email: @support_email,
        support_phone: @support_phone,
        timestamp: @timestamp,
        email: user.email,
        username: user.respond_to?(:username) ? user.username : nil,
        is_lead: user.respond_to?(:is_lead) ? user.is_lead : nil,
        is_manager: user.respond_to?(:is_manager) ? user.is_manager : nil,
        compensation_type: user.respond_to?(:compensation_type) ? user.compensation_type : nil,
        actor_name: actor&.fullname.presence || actor&.email
      }
    )
  end

  # Notify a staff user that their account details were updated by an admin.
  #
  # @param user [Admin, SalesUser, MarketingUser] the updated staff user
  # @param actor [Admin, nil] the admin who performed the action
  # @param changes [Hash{String=>Array}] ActiveRecord-style changes (old, new)
  def account_updated(user, actor: nil, changes: {})
    @user = user
    @actor = actor
    @role = user.class.name.downcase
    @name = user.fullname.presence || user.username.presence || user.email.to_s.split('@').first
    @changes = changes || {}
    @password_changed = @changes.key?('password_digest') || @changes.key?('password')
    @dashboard_url = dashboard_url_for(user)
    @support_email = ENV['BREVO_EMAIL'] || 'support@carboncube.co.ke'
    @support_phone = '+254 712 990 524'
    @timestamp = Time.current.strftime('%B %d, %Y at %I:%M %p')

    mail(
      to: user.email,
      bcc: ENV['BREVO_EMAIL'],
      subject: "Your Carbon Cube Kenya #{@role.capitalize} account was updated",
      react: {
        name: @name,
        role: @role,
        changes: @changes,
        password_changed: @password_changed,
        dashboard_url: @dashboard_url,
        support_email: @support_email,
        support_phone: @support_phone,
        timestamp: @timestamp,
        email: user.email,
        username: user.respond_to?(:username) ? user.username : nil,
        is_lead: user.respond_to?(:is_lead) ? user.is_lead : nil,
        is_manager: user.respond_to?(:is_manager) ? user.is_manager : nil,
        compensation_type: user.respond_to?(:compensation_type) ? user.compensation_type : nil,
        actor_name: actor&.fullname.presence || actor&.email
      }
    )
  end

  private

  def dashboard_url_for(user)
    base = case user.class.name
           when 'Admin'
             'https://carboncube-ke.com/admin/analytics'
           when 'SalesUser'
             'https://carboncube-ke.com/sales/dashboard'
           when 'MarketingUser'
             'https://carboncube-ke.com/marketing/dashboard'
           else
             'https://carboncube-ke.com/'
           end
    UtmUrlHelper.append_utm(
      base,
      source: 'email',
      medium: 'staff_account',
      campaign: 'updated',
      content: 'dashboard'
    )
  end
end
