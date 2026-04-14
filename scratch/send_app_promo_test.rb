require 'open3'
require 'erb'

# Settings
email = 'optisoftkenya@gmail.com'
seller = Seller.find_by(email: email) || Seller.new(email: email, fullname: 'Partner', enterprise_name: 'Optisoft Kenya')

# 1. Define variables for ERB
@seller = seller
@fullname = seller.fullname
@enterprise_name = seller.enterprise_name
@first_name = @fullname.to_s.split(' ').first.presence || "Partner"
utm_params = "utm_source=internal_system&utm_medium=email&utm_campaign=app_launch_2026&utm_content=app_promo"

# 2. Read and process ERB
template_path = Rails.root.join('app', 'views', 'seller_communications_mailer', 'app_promo.mjml')
mjml_template = File.read(template_path)
# Manual ERB evaluation
mjml_source = ERB.new(mjml_template).result(binding)

# 3. Compile MJML to HTML
node_bin = "/Users/Quaint/.nvm/versions/node/v18.20.6/bin/node"
mjml_bin = Rails.root.join('node_modules', 'mjml', 'bin', 'mjml').to_s

stdout, stderr, status = Open3.capture3(
  node_bin,
  mjml_bin,
  '--stdin',
  stdin_data: mjml_source
)

if status.success?
  html_body = stdout
  puts "MJML Compiled Successfully!"
  
  # 4. Send via Mailer directly
  mail = SellerCommunicationsMailer.with(seller: seller).app_promo
  mail.html_part do
    content_type 'text/html; charset=UTF-8'
    body html_body
  end
  
  mail.deliver_now
  puts "Email Sent to #{email}!"
else
  puts "Compilation Failed!"
  puts stderr
end
