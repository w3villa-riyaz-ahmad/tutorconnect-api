module Api
  module Admin
    class DashboardController < ApplicationController
      before_action :admin_only!

      # GET /api/admin/stats
      def stats
        render json: {
          stats: AdminService.platform_stats,
          generated_at: Time.current
        }
      end

      # GET /api/admin/recent_activity
      def recent_activity
        recent_users = User.order(created_at: :desc).limit(5).map do |u|
          { id: u.id, name: u.full_name, email: u.email, role: u.role, created_at: u.created_at }
        end

        recent_calls = Call.includes(:student, :teacher).order(created_at: :desc).limit(5).map do |c|
          {
            id: c.id,
            student: c.student.full_name,
            teacher: c.teacher.full_name,
            status: c.status,
            duration: c.duration,
            created_at: c.created_at
          }
        end

        recent_subscriptions = Subscription.includes(:user).order(created_at: :desc).limit(5).map do |s|
          {
            id: s.id,
            user: s.user.full_name,
            plan_type: s.plan_type,
            status: s.status,
            amount: s.amount ? (s.amount / 100.0).round(2) : nil,
            created_at: s.created_at
          }
        end

        render json: {
          recent_users: recent_users,
          recent_calls: recent_calls,
          recent_subscriptions: recent_subscriptions
        }
      end
    end
  end
end
