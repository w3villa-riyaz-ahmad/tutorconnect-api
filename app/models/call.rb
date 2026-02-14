class Call < ApplicationRecord
  belongs_to :student, class_name: "User"
  belongs_to :teacher, class_name: "User"

  enum :status, { active: 0, ended: 1, dropped: 2 }

  scope :recent, -> { order(created_at: :desc) }
  scope :completed, -> { where(status: [:ended, :dropped]) }

  validates :room_id, presence: true, uniqueness: true

  HEARTBEAT_TIMEOUT = 60.seconds

  def stale?
    last_heartbeat.present? && last_heartbeat < HEARTBEAT_TIMEOUT.ago
  end

  def duration
    return 0 unless started_at
    end_time = ended_at || Time.current
    (end_time - started_at).to_i
  end

  def participant?(user)
    student_id == user.id || teacher_id == user.id
  end
end
