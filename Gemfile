source "https://rubygems.org"

ruby ">= 3.1.0"

gem "rails", "~> 7.1"
gem "mysql2", "~> 0.5"
gem "puma", ">= 5.0"
gem "bootsnap", require: false

# Authentication
gem "bcrypt", "~> 3.1"
gem "jwt", "~> 3.1"
gem "omniauth", "~> 2.1"
gem "omniauth-google-oauth2"
gem "omniauth-github", "~> 2.0"
gem "omniauth-rails_csrf_protection"

# Background Jobs (will add sidekiq in Phase 3)
# gem "sidekiq", "~> 7.0"
# gem "sidekiq-cron", "~> 1.12"

# Payments
gem "stripe", "~> 10.0"

# Image Upload
gem "cloudinary", "~> 1.28"

# CSV Export
gem "csv"

# Pagination
gem "kaminari", "~> 1.2"

# CORS
gem "rack-cors"

# Environment Variables
gem "dotenv-rails", groups: [:development, :test]

# Rate Limiting
gem "rack-attack", "~> 6.7"

group :development, :test do
  gem "debug", platforms: %i[mri mingw x64_mingw]
  gem "rspec-rails", "~> 6.0"
  gem "factory_bot_rails"
  gem "faker"
  # gem "letter_opener" # Replaced by Brevo SMTP
end
