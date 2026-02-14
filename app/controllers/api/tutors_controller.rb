# frozen_string_literal: true

module Api
  class TutorsController < ApplicationController
    before_action :authenticate!
    before_action :require_verified!

    # GET /api/tutors — list available tutors (for students)
    def index
      tutors = User.teacher

      # Filter by status
      case params[:status]
      when "available"
        tutors = tutors.where(tutor_status: :available)
      when "all"
        # show all tutors
      else
        # Default: show available only
        tutors = tutors.where(tutor_status: :available)
      end

      # Search by name
      if params[:search].present?
        search = "%#{params[:search]}%"
        tutors = tutors.where("first_name LIKE ? OR last_name LIKE ?", search, search)
      end

      tutors = tutors.order(:first_name).page(params[:page]).per(20)

      render json: {
        tutors: tutors.map { |t| tutor_response(t) },
        meta: {
          current_page: tutors.current_page,
          total_pages: tutors.total_pages,
          total_count: tutors.total_count
        }
      }
    end

    # GET /api/tutors/:id — single tutor detail
    def show
      tutor = User.teacher.find(params[:id])

      render json: { tutor: tutor_response(tutor) }
    end

    # PATCH /api/tutors/toggle_status — teacher toggles availability
    def toggle_status
      unless current_user.teacher?
        return render json: { error: "Only teachers can toggle availability" }, status: :forbidden
      end

      if current_user.tutor_busy?
        return render json: { error: "You are currently in a call. End the call first." }, status: :conflict
      end

      new_status = current_user.tutor_available? ? :offline : :available
      current_user.update!(tutor_status: new_status)

      render json: {
        message: "Status updated to #{new_status}",
        tutor_status: current_user.tutor_status
      }
    end

    private

    def tutor_response(tutor)
      {
        id: tutor.id,
        first_name: tutor.first_name,
        last_name: tutor.last_name,
        full_name: tutor.full_name,
        email: tutor.email,
        profile_pic_url: tutor.profile_pic_url,
        tutor_status: tutor.tutor_status,
        address: tutor.address,
        created_at: tutor.created_at
      }
    end
  end
end
