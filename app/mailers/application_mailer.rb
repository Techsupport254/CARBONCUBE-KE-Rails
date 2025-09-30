class ApplicationMailer < ActionMailer::Base
  default from: "Carbon Cube Kenya <#{ENV['BREVO_EMAIL']}>"
  
  # Add headers to improve deliverability
  before_action :add_deliverability_headers
  
  private
  
  def add_deliverability_headers
    headers['X-Mailer'] = 'Carbon Cube Kenya Mailer'
    headers['X-Priority'] = '3'
    headers['X-MSMail-Priority'] = 'Normal'
    headers['Importance'] = 'Normal'
    headers['X-Carbon-Cube-Version'] = '1.0'
    headers['List-Unsubscribe'] = '<https://carboncube-ke.com/unsubscribe>'
    headers['List-Unsubscribe-Post'] = 'List-Unsubscribe=One-Click'
    
    # Ensure each email is treated as NEW (not a reply)
    # Generate unique Message-ID with timestamp and random component
    timestamp = Time.current.to_i
    random_id = SecureRandom.hex(8)
    headers['Message-ID'] = "<#{timestamp}-#{random_id}@carboncube-ke.com>"
    
    # Explicitly remove any In-Reply-To or References headers to prevent threading
    headers['In-Reply-To'] = nil
    headers['References'] = nil
    
    # Add return path for better deliverability
    headers['Return-Path'] = ENV['BREVO_EMAIL']
    
    # Add organization header
    headers['Organization'] = 'Carbon Cube Kenya'
    
    # Add content type for better rendering
    headers['Content-Type'] = 'text/html; charset=UTF-8'
    
    # Add Precedence header to prevent threading
    headers['Precedence'] = 'bulk'
    
    # Add X-Auto-Response-Suppress header to prevent auto-replies
    headers['X-Auto-Response-Suppress'] = 'All'
  end
end
