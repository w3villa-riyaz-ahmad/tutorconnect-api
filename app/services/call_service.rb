# frozen_string_literal: true

class CallService
  class CallError < StandardError; end

  # Start a call between a student and a teacher
  def self.start_call(student:, teacher:)
    # Validations
    raise CallError, "Only students can initiate calls" unless student.student?
    raise CallError, "You can only call a teacher" unless teacher.teacher?
    raise CallError, "You need an active subscription to make calls" unless student.has_active_subscription?
    raise CallError, "This tutor is not available right now" unless teacher.tutor_available?
    raise CallError, "You already have an active call" if student_in_active_call?(student)
    raise CallError, "This teacher is already in a call" if teacher_in_active_call?(teacher)

    room_id = generate_room_id

    ActiveRecord::Base.transaction do
      # Mark teacher as busy
      teacher.update!(tutor_status: :busy)

      # Create the call record
      call = Call.create!(
        student: student,
        teacher: teacher,
        room_id: room_id,
        status: :active,
        started_at: Time.current,
        last_heartbeat: Time.current
      )

      call
    end
  end

  # End a call gracefully
  def self.end_call(call:, user:)
    raise CallError, "This call is not active" unless call.active?
    raise CallError, "You are not a participant in this call" unless participant?(call, user)

    ActiveRecord::Base.transaction do
      call.update!(
        status: :ended,
        ended_at: Time.current
      )

      # Free up the teacher
      call.teacher.update!(tutor_status: :available)
    end

    call
  end

  # Record a heartbeat for an active call
  def self.heartbeat(call:, user:)
    raise CallError, "This call is not active" unless call.active?
    raise CallError, "You are not a participant in this call" unless participant?(call, user)

    # Check if subscription has expired during call
    if user.student? && !user.has_active_subscription?
      end_call(call: call, user: user)
      raise CallError, "Your subscription has expired. Call ended."
    end

    call.update!(last_heartbeat: Time.current)
    call
  end

  # Clean up stale calls (heartbeat timed out)
  def self.cleanup_stale_calls
    stale_calls = Call.active.where("last_heartbeat < ?", Call::HEARTBEAT_TIMEOUT.ago)
    count = 0

    stale_calls.find_each do |call|
      call.update!(status: :dropped, ended_at: Time.current)
      call.teacher.update!(tutor_status: :available) if call.teacher.tutor_busy?
      count += 1
    end

    count
  end

  # Get call duration in seconds
  def self.call_duration(call)
    return 0 unless call.started_at
    end_time = call.ended_at || Time.current
    (end_time - call.started_at).to_i
  end

  def self.student_in_active_call?(user)
    Call.active.where(student: user).exists?
  end

  def self.teacher_in_active_call?(user)
    Call.active.where(teacher: user).exists?
  end

  def self.participant?(call, user)
    call.student_id == user.id || call.teacher_id == user.id
  end

  def self.generate_room_id
    "room_#{SecureRandom.hex(8)}_#{Time.current.to_i}"
  end

  private_class_method :generate_room_id
end
