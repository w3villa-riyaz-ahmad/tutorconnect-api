class UserMailer < ApplicationMailer
  def verification_email(user)
    @user = user
    @verification_url = "#{api_base_url}/api/auth/verify_email?token=#{user.verification_token}"
    @frontend_url = ENV.fetch("FRONTEND_URL", "http://localhost:3000")

    Rails.logger.info "[Mailer] Sending verification email to #{user.email}"

    mail(
      to: @user.email,
      subject: "Verify your TutorConnect account",
      reply_to: ENV.fetch("BREVO_SENDER_EMAIL", "noreply@tutorconnect.com")
    )
  rescue StandardError => e
    Rails.logger.error "[Mailer] Failed to send verification email to #{user.email}: #{e.message}"
    raise e
  end

  private

  def api_base_url
    ENV.fetch("API_BASE_URL", "http://localhost:4000")
  end
end
