# frozen_string_literal: true

module Api
  class CallsController < ApplicationController
    before_action :authenticate!
    before_action :require_verified!

    # POST /api/calls/start — student initiates a call with a teacher
    def start
      teacher = User.teacher.find(params[:teacher_id])

      call = CallService.start_call(student: current_user, teacher: teacher)

      render json: {
        message: "Call started successfully",
        call: call_response(call),
        video: video_info(call, current_user)
      }, status: :created

    rescue CallService::CallError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Teacher not found" }, status: :not_found
    end

    # POST /api/calls/end_call — either participant ends the call
    def end_call
      call = find_active_call

      return render json: { error: "No active call found" }, status: :not_found unless call

      CallService.end_call(call: call, user: current_user)

      render json: {
        message: "Call ended",
        call: call_response(call.reload),
        duration: CallService.call_duration(call)
      }

    rescue CallService::CallError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    # POST /api/calls/heartbeat — keep the call alive
    def heartbeat
      call = find_active_call

      return render json: { error: "No active call found" }, status: :not_found unless call

      CallService.heartbeat(call: call, user: current_user)

      render json: {
        status: "alive",
        call: call_response(call.reload),
        subscription_time_remaining: current_user.student? ? current_user.active_subscription&.time_remaining : nil
      }

    rescue CallService::CallError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    # GET /api/calls/active — get current active call for the user (used on page load/refresh)
    def active
      call = find_active_call

      if call
        render json: {
          has_active_call: true,
          call: call_response(call),
          video: video_info(call, current_user)
        }
      else
        render json: { has_active_call: false, call: nil }
      end
    end

    # GET /api/calls/history — past calls for the user
    def history
      calls = if current_user.teacher?
                current_user.teacher_calls
              else
                current_user.student_calls
              end

      calls = calls.where.not(status: :active)
                   .includes(:student, :teacher)
                   .order(created_at: :desc)
                   .page(params[:page])
                   .per(15)

      render json: {
        calls: calls.map { |c| call_response(c) },
        meta: {
          current_page: calls.current_page,
          total_pages: calls.total_pages,
          total_count: calls.total_count
        }
      }
    end

    private

    def find_active_call
      if current_user.teacher?
        Call.active.find_by(teacher: current_user)
      else
        Call.active.find_by(student: current_user)
      end
    end

    def call_response(call)
      {
        id: call.id,
        room_id: call.room_id,
        status: call.status,
        student: {
          id: call.student.id,
          name: call.student.full_name,
          profile_pic_url: call.student.profile_pic_url
        },
        teacher: {
          id: call.teacher.id,
          name: call.teacher.full_name,
          profile_pic_url: call.teacher.profile_pic_url
        },
        started_at: call.started_at,
        ended_at: call.ended_at,
        duration: CallService.call_duration(call),
        last_heartbeat: call.last_heartbeat
      }
    end

    # Return video room info (Jitsi Meet — free, no API key needed)
    def video_info(call, user)
      jitsi_domain = ENV.fetch("JITSI_DOMAIN", "meet.ffmuc.net")
      {
        room_url: call.video_room_url || "https://#{jitsi_domain}/#{call.room_id}",
        room_name: call.room_id,
        domain: jitsi_domain,
        user_name: user.full_name
      }
    end
  end
end
