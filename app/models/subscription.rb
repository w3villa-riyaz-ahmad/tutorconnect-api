class Subscription < ApplicationRecord
  belongs_to :user

  enum :plan_type, { one_hour: 0, six_hour: 1, twelve_hour: 2 }
  enum :status, { active: 0, expired: 1 }

  scope :currently_active, -> { active.where("end_time > ?", Time.current) }
  scope :expired_by_time, -> { active.where("end_time <= ?", Time.current) }

  validates :start_time, :end_time, :plan_type, presence: true
  validate :end_time_after_start_time

  PLAN_DURATIONS = {
    "one_hour"    => 1.hour,
    "six_hour"    => 6.hours,
    "twelve_hour" => 12.hours
  }.freeze

  PLAN_PRICES = {
    "one_hour"    => 999,
    "six_hour"    => 3999,
    "twelve_hour" => 5999
  }.freeze

  def time_remaining
    return 0 if expired? || end_time < Time.current
    (end_time - Time.current).to_i
  end

  def expired_by_time?
    end_time < Time.current
  end

  private

  def end_time_after_start_time
    return unless start_time && end_time
    errors.add(:end_time, "must be after start time") if end_time <= start_time
  end
end
