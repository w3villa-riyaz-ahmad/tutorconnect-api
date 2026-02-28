class ApplicationMailer < ActionMailer::Base
  default from: "#{ENV.fetch('BREVO_SENDER_NAME', 'TutorConnect')} <#{ENV.fetch('BREVO_SENDER_EMAIL', 'noreply@tutorconnect.com')}>"
  layout "mailer"
end
