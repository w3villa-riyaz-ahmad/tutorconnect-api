class User < ApplicationRecord
  has_secure_password validations: false # Allow OAuth users without password

  has_many :subscriptions, dependent: :destroy
  has_many :student_calls, class_name: "Call", foreign_key: :student_id, dependent: :destroy
  has_many :teacher_calls, class_name: "Call", foreign_key: :teacher_id, dependent: :destroy

  enum :role, { student: 0, teacher: 1, admin: 2 }
  enum :tutor_status, { offline: 0, available: 1, busy: 2 }, prefix: :tutor

  scope :active_users, -> { where(banned: false) }
  scope :banned_users, -> { where(banned: true) }

  validates :email, presence: true, uniqueness: { case_sensitive: false },
            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 },
            if: -> { password_digest_changed? || (new_record? && provider.blank?) }
  validates :first_name, presence: true
  validates :last_name, presence: true

  before_save { self.email = email.downcase.strip }

  def full_name
    "#{first_name} #{last_name}"
  end

  def active_subscription
    subscriptions.where(status: :active).where("end_time > ?", Time.current).first
  end

  def has_active_subscription?
    active_subscription.present?
  end

  def generate_verification_token!
    update!(
      verification_token: SecureRandom.urlsafe_base64(32),
      token_sent_at: Time.current
    )
    verification_token
  end

  def in_active_call?
    if teacher?
      teacher_calls.where(status: :active).exists?
    else
      student_calls.where(status: :active).exists?
    end
  end

  def total_calls_count
    if teacher?
      teacher_calls.where(status: [:ended, :dropped]).count
    else
      student_calls.where(status: [:ended, :dropped]).count
    end
  end
end
