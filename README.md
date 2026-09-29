# Carbon Cube Kenya — Rails API

Backend API powering **Carbon Cube Kenya** (carboncube-ke.com), a B2B marketplace
connecting Kenyan buyers with verified sellers. It serves the Next.js web
storefront and the CarbonMobile React Native app.

## Key features

- JWT authentication with WebAuthn passkeys and email OTP verification
- Ads/listings catalogue with categories, counties, brands and full-text
  search via `pg_search`
- WhatsApp product creation — sellers list items through a conversational
  WhatsApp Cloud API flow with AI-assisted brand detection, category
  suggestions, price recommendations and spec fetching
- Realtime buyer–seller conversations over ActionCable
- Background/scheduled jobs with Sidekiq and sidekiq-cron
- Media uploads via ActiveStorage + Cloudinary, PDFs via Prawn, transactional
  email via MJML / React Email
- Hardened for production: Sentry, rack-attack rate limiting, Redis sessions,
  SEO redirects and `/health/*` endpoints

## Tech stack

Ruby 3.4 · Rails 7.1 · PostgreSQL · Redis · Sidekiq · Puma ·
Active Model Serializers · dry-validation · HTTParty

## Setup

```bash
bundle install
cp .env.example .env        # database, Redis, WhatsApp, Cloudinary keys
bin/rails db:setup
bin/rails s                 # API on http://localhost:3000
bundle exec sidekiq         # background worker
```

Lint with `bundle exec rubocop`. Health checks live under `/health`
(`/health/database`, `/health/redis`, `/health/overall`).
