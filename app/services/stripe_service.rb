# frozen_string_literal: true

class StripeService
  class PaymentError < StandardError; end

  # Check if real Stripe keys are configured
  def self.configured?
    ENV["STRIPE_SECRET_KEY"].present? &&
      ENV["STRIPE_SECRET_KEY"] != "sk_test_xxx"
  end

  # Create a Stripe checkout session OR a test subscription (when Stripe not configured)
  def self.create_checkout_session(user:, plan_type:)
    price = Subscription::PLAN_PRICES[plan_type]
    duration = Subscription::PLAN_DURATIONS[plan_type]

    raise PaymentError, "Invalid plan type" unless price && duration

    # If Stripe is not configured, create a test subscription directly
    unless configured?
      return create_test_subscription(user: user, plan_type: plan_type, price: price, duration: duration)
    end

    # Create real Stripe Checkout Session
    session = Stripe::Checkout::Session.create(
      payment_method_types: ["card"],
      customer_email: user.email,
      line_items: [{
        price_data: {
          currency: "usd",
          product_data: {
            name: "TutorConnect — #{plan_type.humanize} Plan",
            description: "#{duration / 3600} hour(s) of tutoring access"
          },
          unit_amount: price
        },
        quantity: 1
      }],
      mode: "payment",
      success_url: "#{ENV['FRONTEND_URL']}/subscriptions/success?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: "#{ENV['FRONTEND_URL']}/subscriptions?canceled=true",
      metadata: {
        user_id: user.id.to_s,
        plan_type: plan_type
      }
    )

    { url: session.url, session_id: session.id }
  end

  # Handle Stripe checkout.session.completed webhook
  def self.handle_checkout_completed(session)
    user_id = session.metadata["user_id"] || session.metadata[:user_id]
    plan_type = session.metadata["plan_type"] || session.metadata[:plan_type]

    user = User.find(user_id)
    duration = Subscription::PLAN_DURATIONS[plan_type]

    raise PaymentError, "Invalid plan in webhook" unless duration

    # Expire any existing active subscriptions
    user.subscriptions.active.update_all(status: :expired)

    now = Time.current
    user.subscriptions.create!(
      plan_type: plan_type,
      start_time: now,
      end_time: now + duration,
      payment_id: session.payment_intent,
      stripe_session_id: session.id,
      amount: session.amount_total,
      status: :active
    )
  end

  # Verify a checkout session by ID
  def self.verify_session(session_id)
    return nil unless configured?
    Stripe::Checkout::Session.retrieve(session_id)
  rescue Stripe::InvalidRequestError
    nil
  end

  # ── Test mode: create subscription without real payment ──

  def self.create_test_subscription(user:, plan_type:, price:, duration:)
    # Expire existing active subscriptions
    user.subscriptions.active.update_all(status: :expired)

    now = Time.current
    subscription = user.subscriptions.create!(
      plan_type: plan_type,
      start_time: now,
      end_time: now + duration,
      payment_id: "test_#{SecureRandom.hex(12)}",
      stripe_session_id: "test_session_#{SecureRandom.hex(8)}",
      amount: price,
      status: :active
    )

    {
      url: "#{ENV['FRONTEND_URL']}/subscriptions/success?test=true",
      session_id: "test_#{subscription.id}",
      subscription: subscription
    }
  end

  private_class_method :create_test_subscription
end
