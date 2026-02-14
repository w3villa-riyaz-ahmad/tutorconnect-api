class CreateSubscriptions < ActiveRecord::Migration[7.2]
  def change
    create_table :subscriptions do |t|
      t.references :user,        null: false, foreign_key: true
      t.integer    :plan_type,   null: false
      t.datetime   :start_time,  null: false
      t.datetime   :end_time,    null: false
      t.string     :payment_id
      t.integer    :status,      default: 0

      t.timestamps
    end

    add_index :subscriptions, [:user_id, :status]
    add_index :subscriptions, :end_time
    add_index :subscriptions, :status
  end
end
