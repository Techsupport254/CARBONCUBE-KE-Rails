# Seed file for internal user exclusions
# This file adds common exclusions for development and testing environments

puts "Creating internal user exclusions..."

# Development environment exclusions
InternalUserExclusion.find_or_create_by(
  identifier_type: 'ip_range',
  identifier_value: '127.0.0.1'
) do |exclusion|
  exclusion.reason = 'Localhost development environment'
  exclusion.active = true
end

InternalUserExclusion.find_or_create_by(
  identifier_type: 'ip_range',
  identifier_value: '192.168.0.0/16'
) do |exclusion|
  exclusion.reason = 'Private network range (common for development)'
  exclusion.active = true
end

InternalUserExclusion.find_or_create_by(
  identifier_type: 'ip_range',
  identifier_value: '10.0.0.0/8'
) do |exclusion|
  exclusion.reason = 'Private network range (common for development)'
  exclusion.active = true
end

# Development tool exclusions
InternalUserExclusion.find_or_create_by(
  identifier_type: 'user_agent',
  identifier_value: 'Chrome.*Headless'
) do |exclusion|
  exclusion.reason = 'Headless Chrome browser (automated testing)'
  exclusion.active = true
end

InternalUserExclusion.find_or_create_by(
  identifier_type: 'user_agent',
  identifier_value: 'PhantomJS'
) do |exclusion|
  exclusion.reason = 'PhantomJS browser (automated testing)'
  exclusion.active = true
end

InternalUserExclusion.find_or_create_by(
  identifier_type: 'user_agent',
  identifier_value: 'Selenium'
) do |exclusion|
  exclusion.reason = 'Selenium WebDriver (automated testing)'
  exclusion.active = true
end

InternalUserExclusion.find_or_create_by(
  identifier_type: 'user_agent',
  identifier_value: 'Puppeteer'
) do |exclusion|
  exclusion.reason = 'Puppeteer browser (automated testing)'
  exclusion.active = true
end

InternalUserExclusion.find_or_create_by(
  identifier_type: 'user_agent',
  identifier_value: 'Chrome-Lighthouse'
) do |exclusion|
  exclusion.reason = 'Lighthouse performance testing tool'
  exclusion.active = true
end

# Development tool patterns
InternalUserExclusion.find_or_create_by(
  identifier_type: 'user_agent',
  identifier_value: 'Chrome DevTools'
) do |exclusion|
  exclusion.reason = 'Chrome Developer Tools'
  exclusion.active = true
end

InternalUserExclusion.find_or_create_by(
  identifier_type: 'user_agent',
  identifier_value: 'Firefox Developer Tools'
) do |exclusion|
  exclusion.reason = 'Firefox Developer Tools'
  exclusion.active = true
end

InternalUserExclusion.find_or_create_by(
  identifier_type: 'user_agent',
  identifier_value: 'Safari Web Inspector'
) do |exclusion|
  exclusion.reason = 'Safari Web Inspector'
  exclusion.active = true
end

# Company-specific exclusions (customize these for your company)
InternalUserExclusion.find_or_create_by(
  identifier_type: 'user_agent',
  identifier_value: 'CarbonCube.*Internal'
) do |exclusion|
  exclusion.reason = 'Internal company browser identifier'
  exclusion.active = true
end

InternalUserExclusion.find_or_create_by(
  identifier_type: 'user_agent',
  identifier_value: 'Company.*Device'
) do |exclusion|
  exclusion.reason = 'Company device identifier'
  exclusion.active = true
end

InternalUserExclusion.find_or_create_by(
  identifier_type: 'user_agent',
  identifier_value: 'Internal.*Browser'
) do |exclusion|
  exclusion.reason = 'Internal browser identifier'
  exclusion.active = true
end

# Testing environment exclusions
InternalUserExclusion.find_or_create_by(
  identifier_type: 'user_agent',
  identifier_value: 'Internal.*Testing'
) do |exclusion|
  exclusion.reason = 'Internal testing environment'
  exclusion.active = true
end

InternalUserExclusion.find_or_create_by(
  identifier_type: 'user_agent',
  identifier_value: 'QA.*Browser'
) do |exclusion|
  exclusion.reason = 'QA testing browser'
  exclusion.active = true
end

InternalUserExclusion.find_or_create_by(
  identifier_type: 'user_agent',
  identifier_value: 'Test.*Environment'
) do |exclusion|
  exclusion.reason = 'Test environment identifier'
  exclusion.active = true
end

puts "Created #{InternalUserExclusion.count} internal user exclusions"
