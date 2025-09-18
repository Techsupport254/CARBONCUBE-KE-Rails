# Use an official Ruby runtime as the base image
FROM ruby:3.4.4

# Install dependencies
RUN apt-get update -qq && apt-get install -y \
  build-essential \
  libpq-dev \
  nodejs \
  cron \
  wget \
  curl

# Set the working directory
WORKDIR /app

# Copy Gemfile and install gems
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy the entire application
COPY . .

# Copy the entrypoint script and make it executable
COPY entrypoint.sh /usr/bin/entrypoint.sh
RUN chmod +x /usr/bin/entrypoint.sh

# Expose the port
EXPOSE 3001

# Use entrypoint.sh to setup cron and start Rails
ENTRYPOINT ["entrypoint.sh"]
CMD ["rails", "server", "-b", "0.0.0.0", "-p", "3001"]
