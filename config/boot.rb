ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.

module Mjml
  def self.valid_mjml_binary
    true
  end
  def self.check_for_custom_mjml_binary
    true
  end
end
