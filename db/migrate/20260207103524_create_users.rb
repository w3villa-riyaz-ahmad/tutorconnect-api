class CreateUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :users do |t|
      t.string   :email,              null: false
      t.string   :password_digest
      t.string   :first_name
      t.string   :last_name
      t.integer  :role,               default: 0, null: false
      t.boolean  :verified,           default: false
      t.string   :provider
      t.string   :uid
      t.integer  :tutor_status,       default: 0
      t.text     :address
      t.decimal  :latitude,           precision: 10, scale: 7
      t.decimal  :longitude,          precision: 10, scale: 7
      t.string   :profile_pic_url
      t.string   :verification_token
      t.datetime :token_sent_at
      t.string   :refresh_token

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, [:provider, :uid], unique: true
    add_index :users, :role
    add_index :users, :tutor_status
    add_index :users, :verification_token, unique: true
  end
end
