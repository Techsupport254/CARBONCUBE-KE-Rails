#!/usr/bin/env bash
# exit on error
set -o errexit

# Unfreeze to allow updating Gemfile.lock
bundle config set frozen false

# Install Ruby dependencies
bundle install

# Install Node dependencies and build React Email templates
npm install
npx react-email-rails-build

# Run migrations and seeds
# bundle exec rake db:migrate
# bundle exec rake db:seed