# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

# Custom Action Mailer delivery method using Brevo's HTTP API (v3)
# instead of SMTP. This avoids SMTP port blocking on platforms like Render.
#
# Usage in production.rb:
#   config.action_mailer.delivery_method = :brevo_api
#
# Required ENV:
#   BREVO_API_KEY          — Brevo v3 API key (starts with "xkeysib-")
#   BREVO_SENDER_EMAIL     — Verified sender email
#   BREVO_SENDER_NAME      — Sender display name

class BrevoApiDelivery
  BREVO_API_URL = "https://api.brevo.com/v3/smtp/email"

  class DeliveryError < StandardError; end

  def initialize(settings = {})
    @api_key = settings[:api_key] || ENV["BREVO_API_KEY"]
  end

  def deliver!(mail)
    raise DeliveryError, "BREVO_API_KEY is not set" if @api_key.blank?

    payload = build_payload(mail)

    uri = URI.parse(BREVO_API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 15
    http.read_timeout = 15

    request = Net::HTTP::Post.new(uri.path)
    request["accept"] = "application/json"
    request["content-type"] = "application/json"
    request["api-key"] = @api_key
    request.body = payload.to_json

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess) || response.code.to_i == 201
      error_body = begin
        JSON.parse(response.body)
      rescue StandardError
        { "message" => response.body }
      end
      Rails.logger.error "[BrevoAPI] Email delivery failed (#{response.code}): #{error_body}"
      raise DeliveryError, "Brevo API error (#{response.code}): #{error_body['message']}"
    end

    Rails.logger.info "[BrevoAPI] Email sent successfully to #{mail.to&.join(', ')}"
    response
  end

  private

  def build_payload(mail)
    # Extract sender from the mail object
    from = mail.from&.first || ENV.fetch("BREVO_SENDER_EMAIL", "noreply@tutorconnect.com")
    sender_name = extract_sender_name(mail) || ENV.fetch("BREVO_SENDER_NAME", "TutorConnect")

    payload = {
      sender: {
        name: sender_name,
        email: from
      },
      to: mail.to.map { |email| { email: email } },
      subject: mail.subject
    }

    # Add reply-to if present
    if mail.reply_to.present?
      payload[:replyTo] = { email: mail.reply_to.first }
    end

    # Add HTML body
    if mail.html_part
      payload[:htmlContent] = mail.html_part.body.to_s
    elsif mail.content_type&.include?("text/html")
      payload[:htmlContent] = mail.body.to_s
    end

    # Add text body
    if mail.text_part
      payload[:textContent] = mail.text_part.body.to_s
    elsif !payload[:htmlContent]
      payload[:textContent] = mail.body.to_s
    end

    payload
  end

  def extract_sender_name(mail)
    # mail[:from] can be "Name <email>" format
    from_field = mail[:from].to_s
    if from_field =~ /\A(.+?)\s*<.+>\z/
      Regexp.last_match(1).strip.delete('"')
    end
  end
end

# Register the delivery method with Action Mailer
ActionMailer::Base.add_delivery_method :brevo_api, BrevoApiDelivery
