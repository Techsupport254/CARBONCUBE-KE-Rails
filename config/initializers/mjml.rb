Mjml.setup do |config|
  # Point to the local mjml binary installed via npm
  config.mjml_binary = "#{Rails.root}/node_modules/.bin/mjml"
  config.use_mrml = false
end
