# frozen_string_literal: true

namespace :calls do
  desc "Clean up stale calls whose heartbeat has timed out"
  task cleanup_stale: :environment do
    count = CallService.cleanup_stale_calls

    if count > 0
      puts "✅ Cleaned up #{count} stale call(s)"
      Rails.logger.info "[CRON] Cleaned up #{count} stale calls"
    else
      puts "ℹ️  No stale calls found"
    end
  end

  desc "Show all active calls"
  task status: :environment do
    active = Call.active.includes(:student, :teacher)

    if active.any?
      puts "Active Calls (#{active.count}):"
      puts "-" * 80
      active.each do |call|
        duration = CallService.call_duration(call)
        mins = duration / 60
        secs = duration % 60
        hb_ago = call.last_heartbeat ? "#{(Time.current - call.last_heartbeat).to_i}s ago" : "never"
        puts "  #{call.room_id} | #{call.student.email} ↔ #{call.teacher.email} | #{mins}m#{secs}s | HB: #{hb_ago}"
      end
    else
      puts "No active calls"
    end
  end
end
