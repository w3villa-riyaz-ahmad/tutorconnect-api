# frozen_string_literal: true

# Configure Stripe only when keys are present and not placeholder values
if ENV["STRIPE_SECRET_KEY"].present? && ENV["STRIPE_SECRET_KEY"] != "sk_test_xxx"
  Stripe.api_key = ENV["STRIPE_SECRET_KEY"]
  Rails.logger.info "✅ Stripe configured with live/test key"
else
  Rails.logger.info "⚠️  Stripe not configured — running in TEST MODE (no real charges)"
end
