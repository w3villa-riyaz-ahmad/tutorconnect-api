class AdminService
  class << self
    # Platform-wide statistics for the admin dashboard
    def platform_stats
      {
        users: user_stats,
        subscriptions: subscription_stats,
        calls: call_stats,
        revenue: revenue_stats
      }
    end

    private

    def user_stats
      {
        total: User.count,
        students: User.student.count,
        teachers: User.teacher.count,
        admins: User.admin.count,
        verified: User.where(verified: true).count,
        unverified: User.where(verified: false).count,
        banned: User.where(banned: true).count,
        new_today: User.where("created_at >= ?", Time.current.beginning_of_day).count,
        new_this_week: User.where("created_at >= ?", 7.days.ago).count,
        new_this_month: User.where("created_at >= ?", 30.days.ago).count,
        teachers_online: User.teacher.where(tutor_status: :available).count,
        teachers_busy: User.teacher.where(tutor_status: :busy).count
      }
    end

    def subscription_stats
      {
        total: Subscription.count,
        active: Subscription.currently_active.count,
        expired: Subscription.where(status: :expired).count +
                 Subscription.expired_by_time.count,
        by_plan: {
          one_hour: Subscription.one_hour.count,
          six_hour: Subscription.six_hour.count,
          twelve_hour: Subscription.twelve_hour.count
        },
        active_by_plan: {
          one_hour: Subscription.currently_active.one_hour.count,
          six_hour: Subscription.currently_active.six_hour.count,
          twelve_hour: Subscription.currently_active.twelve_hour.count
        }
      }
    end

    def call_stats
      {
        total: Call.count,
        active_now: Call.active.count,
        ended: Call.ended.count,
        dropped: Call.dropped.count,
        today: Call.where("created_at >= ?", Time.current.beginning_of_day).count,
        this_week: Call.where("created_at >= ?", 7.days.ago).count,
        this_month: Call.where("created_at >= ?", 30.days.ago).count,
        avg_duration: Call.completed.where.not(started_at: nil, ended_at: nil)
                          .average("TIMESTAMPDIFF(SECOND, started_at, ended_at)")&.to_i || 0
      }
    end

    def revenue_stats
      total_cents = Subscription.where.not(amount: nil).sum(:amount)
      month_cents = Subscription.where.not(amount: nil)
                                .where("created_at >= ?", 30.days.ago)
                                .sum(:amount)
      today_cents = Subscription.where.not(amount: nil)
                                .where("created_at >= ?", Time.current.beginning_of_day)
                                .sum(:amount)

      {
        total: (total_cents / 100.0).round(2),
        this_month: (month_cents / 100.0).round(2),
        today: (today_cents / 100.0).round(2),
        total_transactions: Subscription.where.not(amount: nil).count
      }
    end
  end
end
