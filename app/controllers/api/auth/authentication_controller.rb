module Api
  module Auth
    class AuthenticationController < ApplicationController
      before_action :authenticate!, only: [:logout, :me]

      # POST /api/auth/signup
      def signup
        user = User.new(signup_params)
        user.role = params[:role] || "student"

        if user.save
          # Generate verification token and send email
          token = user.generate_verification_token!
          UserMailer.verification_email(user).deliver_later

          render json: {
            message: "Account created successfully. Please check your email to verify your account.",
            user: user_response(user)
          }, status: :created
        else
          render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # POST /api/auth/login
      def login
        user = User.find_by("LOWER(email) = ?", params[:email]&.downcase&.strip)

        unless user
          return render json: { error: "Invalid email or password" }, status: :unauthorized
        end

        unless user.authenticate(params[:password])
          return render json: { error: "Invalid email or password" }, status: :unauthorized
        end

        unless user.verified?
          return render json: { error: "Please verify your email address before logging in" }, status: :forbidden
        end

        if user.banned?
          return render json: { error: "Your account has been suspended. Contact support for assistance." }, status: :forbidden
        end

        tokens = JwtService.generate_tokens(user)

        render json: {
          message: "Login successful",
          user: user_response(user),
          **tokens
        }
      end

      # POST /api/auth/social
      def social
        provider = params[:provider] # "google" or "github"
        access_token = params[:access_token]

        unless %w[google github].include?(provider)
          return render json: { error: "Unsupported provider" }, status: :bad_request
        end

        # Verify token with the provider and get user info
        user_info = verify_social_token(provider, access_token)

        unless user_info
          return render json: { error: "Invalid social token" }, status: :unauthorized
        end

        # Find or merge user by email (Account Merge Logic)
        user = User.find_by("LOWER(email) = ?", user_info[:email]&.downcase)

        if user
          # Existing user — merge social identity if different provider
          if user.provider.blank? || user.provider != provider
            user.update!(provider: provider, uid: user_info[:uid], verified: true)
          end
        else
          # New user — create with social identity
          user = User.create!(
            email: user_info[:email],
            first_name: user_info[:first_name],
            last_name: user_info[:last_name],
            provider: provider,
            uid: user_info[:uid],
            verified: true,
            role: params[:role] || "student",
            password: SecureRandom.hex(16) # random password for social users
          )
        end

        tokens = JwtService.generate_tokens(user)

        render json: {
          message: "Social login successful",
          user: user_response(user),
          **tokens
        }
      end

      # GET /api/auth/verify_email?token=xxx
      def verify_email
        user = User.find_by(verification_token: params[:token])

        unless user
          return render json: { error: "Invalid or expired verification link" }, status: :bad_request
        end

        # Check if token is older than 24 hours
        if user.token_sent_at && user.token_sent_at < 24.hours.ago
          return render json: { error: "Verification link has expired. Please request a new one." }, status: :bad_request
        end

        user.update!(verified: true, verification_token: nil, token_sent_at: nil)

        # Redirect to frontend login page with success message
        frontend_url = ENV.fetch("FRONTEND_URL", "http://localhost:3000")
        redirect_to "#{frontend_url}/login?verified=true", allow_other_host: true
      end

      # POST /api/auth/github_callback — exchange GitHub code for access token, then login
      def github_callback
        code = params[:code]
        return render json: { error: "Missing authorization code" }, status: :bad_request unless code

        # Exchange code for access token
        token_uri = URI("https://github.com/login/oauth/access_token")
        token_response = Net::HTTP.post_form(token_uri, {
          client_id: ENV["GITHUB_CLIENT_ID"],
          client_secret: ENV["GITHUB_CLIENT_SECRET"],
          code: code
        })

        # Add debugging
        Rails.logger.info "=== GitHub Token Exchange ==="
        Rails.logger.info "Client ID present: #{ENV['GITHUB_CLIENT_ID'].present?}"
        Rails.logger.info "Client Secret present: #{ENV['GITHUB_CLIENT_SECRET'].present?}"
        Rails.logger.info "Code: #{code}"
        Rails.logger.info "Response body: #{token_response.body}"
        Rails.logger.info "=== End GitHub Debug ==="

        # Parse response (it comes as URL-encoded by default)
        token_params = URI.decode_www_form(token_response.body).to_h
        access_token = token_params["access_token"]

        unless access_token
          error_desc = token_params["error_description"] || "Failed to exchange GitHub code"
          Rails.logger.error "GitHub OAuth Error: #{error_desc}"
          return render json: { error: error_desc }, status: :unauthorized
        end

        # Now use the same social flow with the real access token
        user_info = verify_github_token(access_token)

        unless user_info
          return render json: { error: "Failed to fetch GitHub user info" }, status: :unauthorized
        end

        user = User.find_by("LOWER(email) = ?", user_info[:email]&.downcase)

        if user
          if user.banned?
            return render json: { error: "Your account has been suspended. Contact support for assistance." }, status: :forbidden
          end
          if user.provider.blank? || user.provider != "github"
            user.update!(provider: "github", uid: user_info[:uid], verified: true)
          end
        else
          user = User.create!(
            email: user_info[:email],
            first_name: user_info[:first_name],
            last_name: user_info[:last_name],
            provider: "github",
            uid: user_info[:uid],
            verified: true,
            role: params[:role] || "student",
            password: SecureRandom.hex(16)
          )
        end

        tokens = JwtService.generate_tokens(user)

        render json: {
          message: "GitHub login successful",
          user: user_response(user),
          **tokens
        }
      end

      # POST /api/auth/resend_verification
      def resend_verification
        user = User.find_by("LOWER(email) = ?", params[:email]&.downcase&.strip)

        unless user
          # Don't reveal if email exists
          return render json: { message: "If that email exists, a verification link has been sent." }
        end

        if user.verified?
          return render json: { message: "Email is already verified. You can log in." }
        end

        user.generate_verification_token!
        UserMailer.verification_email(user).deliver_later

        render json: { message: "If that email exists, a verification link has been sent." }
      end

      # POST /api/auth/refresh
      def refresh
        tokens = JwtService.refresh(params[:refresh_token])

        unless tokens
          return render json: { error: "Invalid or expired refresh token" }, status: :unauthorized
        end

        render json: tokens
      end

      # POST /api/auth/logout
      def logout
        JwtService.invalidate(current_user)
        render json: { message: "Logged out successfully" }
      end

      # GET /api/auth/me — return current user info
      def me
        render json: { user: user_response(current_user) }
      end

      private

      def signup_params
        params.permit(:email, :password, :first_name, :last_name)
      end

      def user_response(user)
        sub = user.active_subscription
        {
          id: user.id,
          email: user.email,
          first_name: user.first_name,
          last_name: user.last_name,
          role: user.role,
          verified: user.verified,
          profile_pic_url: user.profile_pic_url,
          tutor_status: user.tutor_status,
          has_active_subscription: user.has_active_subscription?,
          active_subscription: sub ? {
            plan_type: sub.plan_type,
            plan_name: sub.plan_type.humanize,
            end_time: sub.end_time,
            time_remaining: sub.time_remaining
          } : nil,
          in_active_call: user.in_active_call?,
          total_calls: user.total_calls_count,
          banned: user.banned,
          created_at: user.created_at
        }
      end

      def verify_social_token(provider, token)
        case provider
        when "google"
          verify_google_token(token)
        when "github"
          verify_github_token(token)
        end
      rescue StandardError => e
        Rails.logger.error "Social auth error: #{e.message}"
        nil
      end

      def verify_google_token(token)
        # Try ID token verification first
        uri = URI("https://oauth2.googleapis.com/tokeninfo?id_token=#{token}")
        response = Net::HTTP.get_response(uri)

        if response.is_a?(Net::HTTPSuccess)
          data = JSON.parse(response.body)

          google_client_id = ENV["GOOGLE_CLIENT_ID"]
          return nil if google_client_id && data["aud"] != google_client_id

          return {
            email: data["email"],
            first_name: data["given_name"] || data["name"]&.split(" ")&.first || "User",
            last_name: data["family_name"] || data["name"]&.split(" ")&.last || "",
            uid: data["sub"]
          }
        end

        # Fallback: treat as access token — fetch user info from Google
        userinfo_uri = URI("https://www.googleapis.com/oauth2/v3/userinfo")
        http = Net::HTTP.new(userinfo_uri.host, userinfo_uri.port)
        http.use_ssl = true
        req = Net::HTTP::Get.new(userinfo_uri)
        req["Authorization"] = "Bearer #{token}"
        userinfo_response = http.request(req)

        return nil unless userinfo_response.is_a?(Net::HTTPSuccess)

        data = JSON.parse(userinfo_response.body)
        return nil unless data["email"]

        {
          email: data["email"],
          first_name: data["given_name"] || data["name"]&.split(" ")&.first || "User",
          last_name: data["family_name"] || data["name"]&.split(" ")&.last || "",
          uid: data["sub"]
        }
      end

      def verify_github_token(token)
        # Verify GitHub access token — get user profile
        uri = URI("https://api.github.com/user")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        request = Net::HTTP::Get.new(uri)
        request["Authorization"] = "Bearer #{token}"
        request["Accept"] = "application/vnd.github+json"
        response = http.request(request)

        Rails.logger.info "=== GitHub User API ==="
        Rails.logger.info "Status: #{response.code}"
        Rails.logger.info "Body: #{response.body[0..500]}"

        return nil unless response.is_a?(Net::HTTPSuccess)

        data = JSON.parse(response.body)

        # GitHub may not expose email publicly — fetch from /user/emails
        email = data["email"]
        unless email
          email_uri = URI("https://api.github.com/user/emails")
          email_req = Net::HTTP::Get.new(email_uri)
          email_req["Authorization"] = "Bearer #{token}"
          email_req["Accept"] = "application/vnd.github+json"
          email_resp = http.request(email_req)

          Rails.logger.info "=== GitHub Emails API ==="
          Rails.logger.info "Status: #{email_resp.code}"
          Rails.logger.info "Body: #{email_resp.body[0..500]}"

          if email_resp.is_a?(Net::HTTPSuccess)
            emails = JSON.parse(email_resp.body)
            primary = emails.find { |e| e["primary"] && e["verified"] }
            email = primary&.dig("email") || emails.first&.dig("email")
          end
        end

        # Fallback: use GitHub noreply email if no email is available
        # (happens when GitHub App lacks user:email permission)
        unless email
          login = data["login"]
          github_id = data["id"]
          if login && github_id
            email = "#{github_id}+#{login}@users.noreply.github.com"
            Rails.logger.info "Using GitHub noreply fallback email: #{email}"
          end
        end

        return nil unless email

        name_parts = (data["name"] || data["login"] || "User").split(" ", 2)

        {
          email: email,
          first_name: name_parts.first || "User",
          last_name: name_parts.last || "",
          uid: data["id"].to_s
        }
      end
    end
  end
end
