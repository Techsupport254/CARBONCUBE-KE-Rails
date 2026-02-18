# syntax = docker/dockerfile:1

# 1. Base stage for shared dependencies
ARG RUBY_VERSION=3.4.4
FROM ruby:$RUBY_VERSION-slim AS base

WORKDIR /app

# Install base packages (essential for running the app)
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    curl \
    libpq5 \
    imagemagick \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# 2. Build stage for installing gems and node modules
FROM base AS build

# Install build dependencies (temporary for compiling gems)
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    git \
    libpq-dev \
    pkg-config \
    nodejs \
    npm && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Install MJML globally for mjml-rails
RUN npm install -g mjml

# Install gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bin/extensions/*/*/*.o

# Copy application code
COPY . .

# Precompile bootsnap for faster boot times
RUN bundle exec bootsnap precompile --gemfile app/ lib/

# 3. Final stage for a small runtime image
FROM base

# Copy built artifacts from build stage
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /app /app

# Ensure tmp directories exist with proper permissions
RUN mkdir -p tmp/pids tmp/cache tmp/sockets tmp/log && \
    chmod -R 777 tmp

EXPOSE 3001
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3001", "-e", "production"]
