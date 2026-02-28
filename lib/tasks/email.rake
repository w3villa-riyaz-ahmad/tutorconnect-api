namespace :email do
  desc "Test Brevo SMTP email delivery"
  task test: :environment do
    puts "Testing Brevo email delivery..."
    puts ""
    puts "SMTP Config:"
    puts "  Host:  #{ENV['BREVO_SMTP_HOST']}"
    puts "  Port:  #{ENV['BREVO_SMTP_PORT']}"
    puts "  Login: #{ENV['BREVO_SMTP_LOGIN']}"
    puts "  Key:   #{ENV['BREVO_SMTP_KEY'].present? ? '✅ Set (hidden)' : '❌ NOT SET'}"
    puts "  From:  #{ENV['BREVO_SENDER_EMAIL']}"
    puts ""

    unless ENV["BREVO_SMTP_KEY"].present?
      puts "❌ BREVO_SMTP_KEY is not set in .env"
      puts "   Please add your Brevo SMTP key to tutorconnect-api/.env"
      exit 1
    end

    email = ENV["TEST_EMAIL"] || ENV["BREVO_SMTP_LOGIN"]

    unless email
      puts "❌ No test email address. Run with: TEST_EMAIL=you@example.com rails email:test"
      exit 1
    end

    puts "Sending test email to: #{email}"

    begin
      ActionMailer::Base.mail(
        from: "#{ENV.fetch('BREVO_SENDER_NAME', 'TutorConnect')} <#{ENV.fetch('BREVO_SENDER_EMAIL', 'noreply@tutorconnect.com')}>",
        to: email,
        subject: "TutorConnect - Brevo Email Test ✅",
        body: "If you're reading this, Brevo SMTP is working correctly!\n\nSent at: #{Time.current}\nEnvironment: #{Rails.env}"
      ).deliver_now

      puts ""
      puts "✅ Email sent successfully! Check your inbox (and spam folder) at: #{email}"
    rescue StandardError => e
      puts ""
      puts "❌ Failed to send email: #{e.message}"
      puts ""
      puts "Troubleshooting:"
      puts "  1. Verify BREVO_SMTP_LOGIN is your Brevo account email"
      puts "  2. Verify BREVO_SMTP_KEY is a valid SMTP key (starts with 'xkeysib-')"
      puts "  3. Check that your Brevo account is activated"
      puts "  4. Make sure BREVO_SENDER_EMAIL matches a verified sender in Brevo"
      exit 1
    end
  end

  desc "Send a test verification email to a user"
  task :verify, [:email] => :environment do |_t, args|
    email = args[:email]
    unless email
      puts "Usage: rails email:verify[user@example.com]"
      exit 1
    end

    user = User.find_by(email: email)
    unless user
      puts "❌ User not found: #{email}"
      exit 1
    end

    puts "Sending verification email to: #{email}"
    UserMailer.verification_email(user).deliver_now
    puts "✅ Verification email sent!"
  end
end
