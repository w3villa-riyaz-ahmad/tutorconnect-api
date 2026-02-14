# frozen_string_literal: true

namespace :subscriptions do
  desc "Expire subscriptions whose end_time has passed"
  task expire_stale: :environment do
    expired = Subscription.expired_by_time

    if expired.any?
      count = expired.count
      expired.update_all(status: :expired)
      puts "✅ Expired #{count} stale subscription(s)"
      Rails.logger.info "[CRON] Expired #{count} stale subscriptions"
    else
      puts "ℹ️  No stale subscriptions found"
    end
  end

  desc "Show all active subscriptions with time remaining"
  task status: :environment do
    active = Subscription.currently_active.includes(:user)

    if active.any?
      puts "Active Subscriptions (#{active.count}):"
      puts "-" * 70
      active.each do |sub|
        remaining = sub.time_remaining
        hours = remaining / 3600
        minutes = (remaining % 3600) / 60
        puts "  #{sub.user.email} | #{sub.plan_type.humanize} | #{hours}h #{minutes}m remaining | ends #{sub.end_time.strftime('%Y-%m-%d %H:%M')}"
      end
    else
      puts "No active subscriptions"
    end
  end
end
