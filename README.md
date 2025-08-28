# CARBON ECOMMERCE BACKEND-Ruby on Rails - SETUP GUIDE

## Introduction

This repository contains a Ruby on Rails application designed for an eCommerce platform. It includes various models and relationships to manage users, sellers, ads, orders, and more.

## Prerequisites

Before getting started, ensure you have the following installed on your system:

- Ruby (version 3.4.4)
- Ruby on Rails (version 8.0.2)
- PostgreSQL (version 17)

## Getting Started

Follow these steps to set up and run the application locally:

### 1. Clone the Repository

```bash
git clone https://github.com/LewKM/CARBONCUBE-KE-Rails.git
cd CARBONCUBE-KE-Rails
```

### 2. Install Dependencies and Setup Database

Run the following command to setup dependencies, create the database, run migrations, and seed data (if available):

```bash
bundle exec rake setup:all
```

This command performs the following tasks sequentially:

- Installs Ruby gems specified in `Gemfile` using `bundle install`.
- Creates PostgreSQL databases for development and test environments using `rails db:create`.
- Executes database migrations to set up tables using `rails db:migrate`.
- Seeds the database with initial data using `rails db:seed` (if seed data is available).

### 3. Start the Rails Server

```bash
rails server
```

The application should now be running locally. You can access it at `http://localhost:3000`.

## Usage

Describe how to use the application, including how to navigate through different features and functionalities.

## Contributing

If you'd like to contribute to this project, please follow these steps:

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/YourFeature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin feature/YourFeature`)
5. Create a new Pull Request

## License

Specify the license under which the code is distributed, if applicable.

## Acknowledgements

Mention any acknowledgements or credits for third-party libraries, resources, or inspiration used in the project.

## Developed by : [Lewis Mwendwa Kathembe](https://www.linkedin.com/in/lewis-mwendwa-3a2581244/)
