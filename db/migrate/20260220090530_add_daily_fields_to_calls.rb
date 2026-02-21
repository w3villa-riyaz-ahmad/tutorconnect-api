class AddDailyFieldsToCalls < ActiveRecord::Migration[7.2]
  def change
    add_column :calls, :daily_room_url, :string
    add_column :calls, :student_token, :text
    add_column :calls, :teacher_token, :text
  end
end
