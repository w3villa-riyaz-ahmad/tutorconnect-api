require "csv"

module Api
  class ProfilesController < ApplicationController
    before_action :authenticate!

    # GET /api/profile
    def show
      render json: { profile: profile_response(current_user) }
    end

    # PUT /api/profile
    def update
      user = current_user

      # Handle profile picture upload
      if params[:profile_pic].present?
        begin
          # Delete old picture if exists
          CloudinaryService.delete_image(user.profile_pic_url) if user.profile_pic_url.present?

          # Upload new picture
          new_url = CloudinaryService.upload_profile_pic(params[:profile_pic], user.id)
          user.profile_pic_url = new_url
        rescue CloudinaryService::UploadError => e
          return render json: { error: e.message }, status: :unprocessable_entity
        end
      end

      # Update text fields
      user.assign_attributes(profile_params)

      if user.save
        render json: {
          message: "Profile updated successfully",
          profile: profile_response(user)
        }
      else
        render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # DELETE /api/profile/remove_photo
    def remove_photo
      user = current_user

      if user.profile_pic_url.present?
        CloudinaryService.delete_image(user.profile_pic_url)
        user.update!(profile_pic_url: nil)
      end

      render json: {
        message: "Profile photo removed",
        profile: profile_response(user)
      }
    end

    # GET /api/profile/download
    def download
      user = current_user
      subscriptions = user.subscriptions.order(created_at: :desc)

      csv_data = CSV.generate(headers: true) do |csv|
        # User info section
        csv << ["=== USER PROFILE ==="]
        csv << ["Field", "Value"]
        csv << ["Name", user.full_name]
        csv << ["Email", user.email]
        csv << ["Role", user.role]
        csv << ["Verified", user.verified? ? "Yes" : "No"]
        csv << ["Address", user.address || "Not set"]
        csv << ["Latitude", user.latitude || "N/A"]
        csv << ["Longitude", user.longitude || "N/A"]
        csv << ["Profile Picture", user.profile_pic_url || "Not set"]
        csv << ["Member Since", user.created_at.strftime("%B %d, %Y")]
        csv << []

        # Subscriptions section
        csv << ["=== SUBSCRIPTION HISTORY ==="]
        csv << ["Plan", "Status", "Start Time", "End Time", "Payment ID"]
        subscriptions.each do |sub|
          csv << [
            sub.plan_type.humanize,
            sub.status,
            sub.start_time.strftime("%Y-%m-%d %H:%M"),
            sub.end_time.strftime("%Y-%m-%d %H:%M"),
            sub.payment_id || "N/A"
          ]
        end

        if subscriptions.empty?
          csv << ["No subscriptions yet"]
        end
      end

      send_data csv_data,
                filename: "tutorconnect_profile_#{user.id}_#{Date.current}.csv",
                type: "text/csv",
                disposition: "attachment"
    end

    private

    def profile_params
      params.permit(:first_name, :last_name, :address, :latitude, :longitude)
    end

    def profile_response(user)
      {
        id: user.id,
        email: user.email,
        first_name: user.first_name,
        last_name: user.last_name,
        role: user.role,
        verified: user.verified,
        profile_pic_url: user.profile_pic_url,
        address: user.address,
        latitude: user.latitude&.to_f,
        longitude: user.longitude&.to_f,
        tutor_status: user.tutor_status,
        has_active_subscription: user.has_active_subscription?,
        created_at: user.created_at,
        updated_at: user.updated_at
      }
    end
  end
end
