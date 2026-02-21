class RemoveDailyFieldsFromCalls < ActiveRecord::Migration[7.2]
  def change
    # Rename daily_room_url → video_room_url
    rename_column :calls, :daily_room_url, :video_room_url

    # Remove unused Daily.co token columns
    remove_column :calls, :student_token, :text
    remove_column :calls, :teacher_token, :text
  end
end
