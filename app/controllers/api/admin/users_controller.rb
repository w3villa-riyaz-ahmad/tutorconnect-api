module Api
  module Admin
    class UsersController < ApplicationController
      before_action :admin_only!
      before_action :set_user, only: [:show, :update, :ban, :unban]

      # GET /api/admin/users
      def index
        users = User.all

        # Filter by role
        if params[:role].present? && %w[student teacher admin].include?(params[:role])
          users = users.where(role: params[:role])
        end

        # Filter by status (banned/active/unverified)
        case params[:status]
        when "banned"
          users = users.where(banned: true)
        when "active"
          users = users.where(banned: false, verified: true)
        when "unverified"
          users = users.where(verified: false)
        end

        # Search by name or email
        if params[:search].present?
          query = "%#{params[:search]}%"
          users = users.where(
            "first_name LIKE :q OR last_name LIKE :q OR email LIKE :q",
            q: query
          )
        end

        # Sorting
        sort_by = %w[created_at email first_name role].include?(params[:sort_by]) ? params[:sort_by] : "created_at"
        sort_dir = params[:sort_dir] == "asc" ? :asc : :desc
        users = users.order(sort_by => sort_dir)

        # Pagination
        users = users.page(params[:page] || 1).per(params[:per_page] || 15)

        render json: {
          users: users.map { |u| user_summary(u) },
          pagination: {
            current_page: users.current_page,
            total_pages: users.total_pages,
            total_count: users.total_count,
            per_page: users.limit_value
          }
        }
      end

      # GET /api/admin/users/:id
      def show
        render json: { user: user_detail(@user) }
      end

      # PATCH /api/admin/users/:id
      def update
        # Only allow updating role and verified status
        allowed = {}
        allowed[:role] = params[:role] if params[:role].present? && %w[student teacher admin].include?(params[:role])
        allowed[:verified] = params[:verified] if params.key?(:verified)
        allowed[:first_name] = params[:first_name] if params[:first_name].present?
        allowed[:last_name] = params[:last_name] if params[:last_name].present?

        if allowed.empty?
          return render json: { error: "No valid fields to update" }, status: :unprocessable_entity
        end

        # Prevent admin from changing their own role
        if allowed.key?(:role) && @user.id == current_user.id
          return render json: { error: "You cannot change your own role" }, status: :forbidden
        end

        @user.update!(allowed)

        render json: {
          message: "User updated successfully",
          user: user_detail(@user)
        }
      end

      # POST /api/admin/users/:id/ban
      def ban
        if @user.id == current_user.id
          return render json: { error: "You cannot ban yourself" }, status: :forbidden
        end

        if @user.admin?
          return render json: { error: "Cannot ban another admin" }, status: :forbidden
        end

        if @user.banned?
          return render json: { error: "User is already banned" }, status: :unprocessable_entity
        end

        @user.update!(
          banned: true,
          banned_at: Time.current,
          ban_reason: params[:reason] || "Banned by admin"
        )

        # End any active calls
        @user.student_calls.active.update_all(status: :ended, ended_at: Time.current)
        @user.teacher_calls.active.each do |call|
          call.update!(status: :ended, ended_at: Time.current)
          call.teacher.update!(tutor_status: :offline) if call.teacher_id == @user.id
        end

        # Set teacher offline
        @user.update!(tutor_status: :offline) if @user.teacher?

        render json: {
          message: "User has been banned",
          user: user_detail(@user.reload)
        }
      end

      # POST /api/admin/users/:id/unban
      def unban
        unless @user.banned?
          return render json: { error: "User is not banned" }, status: :unprocessable_entity
        end

        @user.update!(
          banned: false,
          banned_at: nil,
          ban_reason: nil
        )

        render json: {
          message: "User has been unbanned",
          user: user_detail(@user.reload)
        }
      end

      private

      def set_user
        @user = User.find(params[:id])
      end

      def user_summary(user)
        {
          id: user.id,
          email: user.email,
          first_name: user.first_name,
          last_name: user.last_name,
          full_name: user.full_name,
          role: user.role,
          verified: user.verified,
          banned: user.banned,
          tutor_status: user.tutor_status,
          profile_pic_url: user.profile_pic_url,
          created_at: user.created_at
        }
      end

      def user_detail(user)
        sub = user.active_subscription
        {
          id: user.id,
          email: user.email,
          first_name: user.first_name,
          last_name: user.last_name,
          full_name: user.full_name,
          role: user.role,
          verified: user.verified,
          banned: user.banned,
          banned_at: user.banned_at,
          ban_reason: user.ban_reason,
          tutor_status: user.tutor_status,
          profile_pic_url: user.profile_pic_url,
          address: user.address,
          provider: user.provider,
          has_active_subscription: user.has_active_subscription?,
          active_subscription: sub ? {
            id: sub.id,
            plan_type: sub.plan_type,
            plan_name: sub.plan_type.humanize,
            status: sub.status,
            start_time: sub.start_time,
            end_time: sub.end_time,
            time_remaining: sub.time_remaining
          } : nil,
          in_active_call: user.in_active_call?,
          total_calls: user.total_calls_count,
          total_subscriptions: user.subscriptions.count,
          created_at: user.created_at,
          updated_at: user.updated_at
        }
      end
    end
  end
end
