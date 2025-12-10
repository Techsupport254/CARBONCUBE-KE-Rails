FROM ruby:3.4.4

RUN apt-get update -qq && apt-get install -y build-essential libpq-dev nodejs && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

# Create tmp directories and set proper permissions
RUN mkdir -p tmp/pids tmp/cache tmp/sockets tmp/log && \
    chmod -R 777 tmp && \
    chown -R 1000:1000 tmp

# Ensure tmp directories exist with proper permissions at runtime
RUN echo '#!/bin/bash\n\
# Fix permissions on existing tmp directory\n\
chmod -R 777 tmp 2>/dev/null || true\n\
# Create tmp directories if they do not exist\n\
mkdir -p tmp/pids tmp/cache tmp/sockets tmp/log 2>/dev/null || true\n\
# Set proper permissions\n\
chmod -R 777 tmp 2>/dev/null || true\n\
# Execute the command\n\
exec "$@"' > /usr/local/bin/start.sh && \
    chmod +x /usr/local/bin/start.sh

EXPOSE 3001
CMD ["/usr/local/bin/start.sh", "rails", "server", "-b", "0.0.0.0", "-p", "3001"]
