FROM ruby:3.4.4

RUN apt-get update -qq && apt-get install -y build-essential libpq-dev nodejs && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

RUN mkdir -p tmp/pids tmp/cache tmp/sockets tmp/log && \
    chmod -R 755 tmp

EXPOSE 3001
CMD ["rails", "server", "-b", "0.0.0.0", "-p", "3001"]
