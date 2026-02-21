# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2026_02_20_130911) do
  create_table "calls", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "student_id", null: false
    t.bigint "teacher_id", null: false
    t.string "room_id", null: false
    t.integer "status", default: 0
    t.datetime "started_at"
    t.datetime "ended_at"
    t.datetime "last_heartbeat"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "video_room_url"
    t.index ["last_heartbeat"], name: "index_calls_on_last_heartbeat"
    t.index ["room_id"], name: "index_calls_on_room_id", unique: true
    t.index ["status"], name: "index_calls_on_status"
    t.index ["student_id"], name: "index_calls_on_student_id"
    t.index ["teacher_id"], name: "index_calls_on_teacher_id"
  end

  create_table "subscriptions", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "plan_type", null: false
    t.datetime "start_time", null: false
    t.datetime "end_time", null: false
    t.string "payment_id"
    t.integer "status", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "stripe_session_id"
    t.integer "amount"
    t.index ["end_time"], name: "index_subscriptions_on_end_time"
    t.index ["status"], name: "index_subscriptions_on_status"
    t.index ["stripe_session_id"], name: "index_subscriptions_on_stripe_session_id", unique: true
    t.index ["user_id", "status"], name: "index_subscriptions_on_user_id_and_status"
    t.index ["user_id"], name: "index_subscriptions_on_user_id"
  end

  create_table "users", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest"
    t.string "first_name"
    t.string "last_name"
    t.integer "role", default: 0, null: false
    t.boolean "verified", default: false
    t.string "provider"
    t.string "uid"
    t.integer "tutor_status", default: 0
    t.text "address"
    t.decimal "latitude", precision: 10, scale: 7
    t.decimal "longitude", precision: 10, scale: 7
    t.string "profile_pic_url"
    t.string "verification_token"
    t.datetime "token_sent_at"
    t.string "refresh_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "banned", default: false, null: false
    t.datetime "banned_at"
    t.string "ban_reason"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
    t.index ["role"], name: "index_users_on_role"
    t.index ["tutor_status"], name: "index_users_on_tutor_status"
    t.index ["verification_token"], name: "index_users_on_verification_token", unique: true
  end

  add_foreign_key "calls", "users", column: "student_id"
  add_foreign_key "calls", "users", column: "teacher_id"
  add_foreign_key "subscriptions", "users"
end
