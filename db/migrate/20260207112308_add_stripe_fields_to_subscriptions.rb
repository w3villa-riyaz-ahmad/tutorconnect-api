class AddStripeFieldsToSubscriptions < ActiveRecord::Migration[7.2]
  def change
    add_column :subscriptions, :stripe_session_id, :string
    add_column :subscriptions, :amount, :integer
    add_index :subscriptions, :stripe_session_id, unique: true
  end
end
