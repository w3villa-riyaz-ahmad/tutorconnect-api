# frozen_string_literal: true

module Api
  class SubscriptionsController < ApplicationController
    before_action :authenticate!
    before_action :require_verified!

    # POST /api/subscriptions/checkout
    # Body: { plan_type: "one_hour" | "six_hour" | "twelve_hour" }
    def checkout
      plan_type = params.require(:plan_type)

      unless Subscription::PLAN_PRICES.key?(plan_type)
        return render json: {
          error: "Invalid plan type. Choose from: #{Subscription::PLAN_PRICES.keys.join(', ')}"
        }, status: :unprocessable_entity
      end

      # Check if user already has an active subscription
      if current_user.has_active_subscription?
        return render json: {
          error: "You already have an active subscription. Wait for it to expire or contact support."
        }, status: :conflict
      end

      result = StripeService.create_checkout_session(
        user: current_user,
        plan_type: plan_type
      )

      render json: {
        message: "Checkout session created",
        url: result[:url],
        session_id: result[:session_id],
        test_mode: !StripeService.configured?
      }, status: :ok

    rescue StripeService::PaymentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue Stripe::StripeError => e
      render json: { error: "Payment error: #{e.message}" }, status: :unprocessable_entity
    end

    # GET /api/subscriptions/current
    def current
      subscription = current_user.active_subscription

      if subscription
        render json: {
          subscription: format_subscription(subscription),
          has_active: true
        }
      else
        render json: {
          subscription: nil,
          has_active: false
        }
      end
    end

    # GET /api/subscriptions/history
    def history
      subscriptions = current_user.subscriptions
                                   .order(created_at: :desc)
                                   .page(params[:page])
                                   .per(10)

      render json: {
        subscriptions: subscriptions.map { |s| format_subscription(s) },
        meta: {
          current_page: subscriptions.current_page,
          total_pages: subscriptions.total_pages,
          total_count: subscriptions.total_count
        }
      }
    end

    # GET /api/subscriptions/plans
    def plans
      plan_list = Subscription::PLAN_PRICES.map do |key, price|
        {
          plan_type: key,
          name: key.humanize,
          price_cents: price,
          price_display: "$#{'%.2f' % (price / 100.0)}",
          duration_hours: Subscription::PLAN_DURATIONS[key] / 3600,
          duration_display: format_plan_duration(Subscription::PLAN_DURATIONS[key])
        }
      end

      render json: {
        plans: plan_list,
        test_mode: !StripeService.configured?,
        stripe_publishable_key: StripeService.configured? ? ENV["STRIPE_PUBLISHABLE_KEY"] : nil
      }
    end

    # GET /api/subscriptions/success?session_id=xxx or ?test=true
    def success
      subscription = nil

      if params[:test] == "true"
        # Test mode — just return the latest active subscription
        subscription = current_user.active_subscription
      elsif params[:session_id].present?
        # Find by stripe session
        subscription = current_user.subscriptions.find_by(stripe_session_id: params[:session_id])

        # If webhook hasn't fired yet, verify the session directly
        if subscription.nil? && StripeService.configured?
          session = StripeService.verify_session(params[:session_id])
          if session&.payment_status == "paid"
            subscription = StripeService.handle_checkout_completed(session)
          end
        end
      end

      if subscription
        render json: {
          message: "Subscription activated successfully!",
          subscription: format_subscription(subscription)
        }
      else
        render json: { error: "Subscription not found or payment pending" }, status: :not_found
      end
    end

    private

    def format_subscription(sub)
      {
        id: sub.id,
        plan_type: sub.plan_type,
        plan_name: sub.plan_type.humanize,
        status: sub.status,
        start_time: sub.start_time,
        end_time: sub.end_time,
        time_remaining: sub.time_remaining,
        time_remaining_display: format_duration(sub.time_remaining),
        amount: sub.amount,
        amount_display: sub.amount ? "$#{'%.2f' % (sub.amount / 100.0)}" : nil,
        payment_id: sub.payment_id,
        created_at: sub.created_at
      }
    end

    def format_duration(seconds)
      return "Expired" if seconds <= 0

      hours = seconds / 3600
      minutes = (seconds % 3600) / 60
      secs = seconds % 60

      parts = []
      parts << "#{hours}h" if hours > 0
      parts << "#{minutes}m" if minutes > 0
      parts << "#{secs}s" if hours == 0 && secs > 0
      parts.empty? ? "< 1s" : parts.join(" ")
    end

    def format_plan_duration(seconds)
      hours = seconds / 3600
      hours == 1 ? "1 Hour" : "#{hours} Hours"
    end
  end
end
