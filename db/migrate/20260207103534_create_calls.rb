class CreateCalls < ActiveRecord::Migration[7.2]
  def change
    create_table :calls do |t|
      t.references :student,      null: false, foreign_key: { to_table: :users }
      t.references :teacher,      null: false, foreign_key: { to_table: :users }
      t.string     :room_id,      null: false
      t.integer    :status,       default: 0
      t.datetime   :started_at
      t.datetime   :ended_at
      t.datetime   :last_heartbeat

      t.timestamps
    end

    add_index :calls, :room_id, unique: true
    add_index :calls, :status
    add_index :calls, :last_heartbeat
  end
end
