# frozen_string_literal: true

module Api
  class WebhooksController < ApplicationController
    # Skip CSRF and authentication for webhooks
    skip_before_action :verify_authenticity_token, raise: false

    # POST /api/webhooks/stripe
    def stripe
      payload = request.body.read
      sig_header = request.env["HTTP_STRIPE_SIGNATURE"]

      begin
        if ENV["STRIPE_WEBHOOK_SECRET"].present? && ENV["STRIPE_WEBHOOK_SECRET"] != "whsec_xxx"
          event = Stripe::Webhook.construct_event(
            payload, sig_header, ENV["STRIPE_WEBHOOK_SECRET"]
          )
        else
          # Dev mode — parse without signature verification
          data = JSON.parse(payload, symbolize_names: true)
          event = Stripe::Event.construct_from(data)
        end
      rescue JSON::ParserError
        return render json: { error: "Invalid payload" }, status: :bad_request
      rescue Stripe::SignatureVerificationError
        return render json: { error: "Invalid signature" }, status: :bad_request
      end

      case event.type
      when "checkout.session.completed"
        session = event.data.object
        StripeService.handle_checkout_completed(session)
        Rails.logger.info "✅ Checkout completed for session: #{session.id}"
      when "payment_intent.payment_failed"
        Rails.logger.warn "❌ Payment failed: #{event.data.object.id}"
      else
        Rails.logger.info "ℹ️  Unhandled Stripe event: #{event.type}"
      end

      render json: { received: true }, status: :ok
    end
  end
end
