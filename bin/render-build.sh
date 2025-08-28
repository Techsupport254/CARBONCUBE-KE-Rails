#!/usr/bin/env bash
# exit on error
set -o errexit

# Unfreeze to allow updating Gemfile.lock
bundle config set frozen false

# Install dependencies
bundle install
 
# Run migrations and seeds
# bundle exec rake db:migrate
# bundle exec rake db:seed  