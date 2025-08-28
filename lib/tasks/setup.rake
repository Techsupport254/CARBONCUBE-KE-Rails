require 'dotenv'
Dotenv.load

namespace :setup do
  desc 'Setup Rails application'
  task :all => [:bundle_install, :db_setup]

  task :bundle_install do
    puts 'Running bundle install...'
    system('bundle install') || raise('Bundle install failed')
  end

  def establish_connection
    connection_string = ENV['DATABASE_URL'] || "postgresql://#{ENV['PGUSER']}:#{ENV['PGPASSWORD']}@#{ENV['PGHOST']}/#{ENV['PGDATABASE']}?sslmode=require"
    ActiveRecord::Base.establish_connection(connection_string)
  end

  task :db_setup => [ :db_migrate, :db_seed]

  # task :db_create do
  #   puts 'Creating database...'
  #   system('rails db:create') || raise('Database creation failed')
  # end

  task :db_migrate do
    begin
      establish_connection
      if ActiveRecord::Base.connection
        puts 'Running migrations...'
        system('rails db:migrate') || raise('Migration failed')
      end
    rescue ActiveRecord::NoDatabaseError
      puts 'Database does not exist. Skipping migrations...'
    rescue PG::ConnectionBad => e
      puts "Connection failed: #{e.message}"
    end
  end

  task :db_seed do
    begin
      establish_connection
      if ActiveRecord::Base.connection
        puts 'Seeding data for the database...'
        system('rails db:seed') || raise('Seeding failed')
      end
    rescue ActiveRecord::NoDatabaseError
      puts 'Database does not exist. Skipping seeding...'
    rescue PG::ConnectionBad => e
      puts "Connection failed: #{e.message}"
    end
  end
end
