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

ActiveRecord::Schema[7.1].define(version: 2026_09_19_235100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "api_keys", force: :cascade do |t|
    t.string "name", null: false
    t.string "token_digest", null: false
    t.string "token_prefix", null: false
    t.boolean "enabled", default: true, null: false
    t.date "renewal_on"
    t.datetime "last_used_at"
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token_digest"], name: "index_api_keys_on_token_digest", unique: true
    t.index ["user_id"], name: "index_api_keys_on_user_id"
  end

  create_table "appointment_notes", force: :cascade do |t|
    t.bigint "booking_id", null: false
    t.bigint "patient_id", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["booking_id"], name: "index_appointment_notes_on_booking_id"
    t.index ["patient_id"], name: "index_appointment_notes_on_patient_id"
  end

  create_table "audit_events", force: :cascade do |t|
    t.bigint "user_id"
    t.string "action", null: false
    t.string "auditable_type"
    t.bigint "auditable_id"
    t.text "details"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["auditable_type", "auditable_id"], name: "index_audit_events_on_auditable_type_and_auditable_id"
    t.index ["user_id"], name: "index_audit_events_on_user_id"
  end

  create_table "bookings", force: :cascade do |t|
    t.bigint "professional_id", null: false
    t.bigint "room_id", null: false
    t.datetime "start_time"
    t.datetime "end_time"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "invoice_id"
    t.decimal "amount", precision: 10, scale: 2
    t.string "billing_type"
    t.datetime "cancelled_at"
    t.text "cancellation_reason"
    t.datetime "rescheduled_from"
    t.string "recurrence_group_id"
    t.datetime "reminder_sent_at"
    t.bigint "patient_id"
    t.index ["invoice_id"], name: "index_bookings_on_invoice_id"
    t.index ["patient_id"], name: "index_bookings_on_patient_id"
    t.index ["professional_id"], name: "index_bookings_on_professional_id"
    t.index ["recurrence_group_id"], name: "index_bookings_on_recurrence_group_id"
    t.index ["room_id"], name: "index_bookings_on_room_id"
  end

  create_table "clinic_integrations", force: :cascade do |t|
    t.string "provider", null: false
    t.boolean "enabled", default: false, null: false
    t.datetime "connected_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "config", default: {}, null: false
    t.string "name", null: false
    t.string "kind", null: false
    t.text "notes"
    t.index ["kind"], name: "index_clinic_integrations_on_kind"
    t.index ["provider"], name: "index_clinic_integrations_on_provider", unique: true
  end

  create_table "invoices", force: :cascade do |t|
    t.bigint "professional_id", null: false
    t.decimal "amount"
    t.string "status"
    t.date "due_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "room_id"
    t.text "notes"
    t.datetime "paid_at"
    t.datetime "refunded_at"
    t.decimal "refunded_amount", precision: 10, scale: 2, default: "0.0"
    t.text "refund_reason"
    t.datetime "cancelled_at"
    t.text "cancellation_reason"
    t.decimal "cancellation_fee", precision: 10, scale: 2, default: "0.0"
    t.datetime "reminder_sent_at"
    t.string "pix_txid"
    t.index ["pix_txid"], name: "index_invoices_on_pix_txid", unique: true
    t.index ["professional_id"], name: "index_invoices_on_professional_id"
    t.index ["room_id"], name: "index_invoices_on_room_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "actor_id"
    t.string "notifiable_type", null: false
    t.bigint "notifiable_id", null: false
    t.string "kind", null: false
    t.string "title", null: false
    t.text "body"
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_notifications_on_actor_id"
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable"
    t.index ["user_id", "created_at"], name: "index_notifications_on_user_id_and_created_at"
    t.index ["user_id", "read_at"], name: "index_notifications_on_user_id_and_read_at"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "outbound_emails", force: :cascade do |t|
    t.string "to_address", null: false
    t.string "cc"
    t.string "bcc"
    t.string "from_address"
    t.string "subject"
    t.string "mailer"
    t.string "action_name"
    t.string "status", default: "sent", null: false
    t.text "body_html"
    t.text "body_text"
    t.text "error_message"
    t.datetime "sent_at"
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "message_id"
    t.datetime "bounced_at"
    t.index ["message_id"], name: "index_outbound_emails_on_message_id"
    t.index ["sent_at"], name: "index_outbound_emails_on_sent_at"
    t.index ["status"], name: "index_outbound_emails_on_status"
    t.index ["to_address"], name: "index_outbound_emails_on_to_address"
    t.index ["user_id"], name: "index_outbound_emails_on_user_id"
  end

  create_table "patients", force: :cascade do |t|
    t.bigint "professional_id", null: false
    t.string "name"
    t.string "contact"
    t.text "history"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["professional_id"], name: "index_patients_on_professional_id"
  end

  create_table "professionals", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "specialty"
    t.string "license_number"
    t.text "bio"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "phone"
    t.string "practice_areas", default: [], array: true
    t.index ["user_id"], name: "index_professionals_on_user_id"
  end

  create_table "room_blocks", force: :cascade do |t|
    t.bigint "room_id"
    t.datetime "starts_at", null: false
    t.datetime "ends_at", null: false
    t.string "reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "weekdays", default: [], array: true
    t.index ["room_id", "starts_at", "ends_at"], name: "index_room_blocks_on_room_id_and_starts_at_and_ends_at"
    t.index ["room_id"], name: "index_room_blocks_on_room_id"
  end

  create_table "rooms", force: :cascade do |t|
    t.string "name"
    t.integer "capacity"
    t.text "equipment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "daily_rate", precision: 10, scale: 2, default: "0.0"
    t.decimal "monthly_rate", precision: 10, scale: 2, default: "0.0"
    t.decimal "hourly_rate", precision: 10, scale: 2
    t.integer "opens_at", default: 8
    t.integer "closes_at", default: 18
    t.string "room_types", default: [], array: true
    t.integer "closed_weekdays", default: [], array: true
  end

  create_table "settings", force: :cascade do |t|
    t.string "clinic_name", default: "MedWork Hub", null: false
    t.string "clinic_email"
    t.string "clinic_phone"
    t.string "currency", default: "BRL", null: false
    t.integer "slot_minutes", default: 30, null: false
    t.integer "saturday_opens_at", default: 9, null: false
    t.integer "saturday_closes_at", default: 12, null: false
    t.boolean "sunday_closed", default: true, null: false
    t.integer "free_cancel_hours", default: 24, null: false
    t.integer "late_cancel_percent", default: 50, null: false
    t.integer "started_cancel_percent", default: 100, null: false
    t.string "week_starts_on", default: "sunday", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "pix_key"
    t.string "pix_name"
    t.string "pix_city"
    t.string "whatsapp_phone"
    t.string "smtp_address"
    t.integer "smtp_port"
    t.string "smtp_domain"
    t.string "smtp_username"
    t.string "smtp_password"
    t.string "smtp_authentication"
    t.boolean "smtp_enable_starttls", default: true, null: false
    t.string "mailer_from"
    t.string "mailer_host"
    t.integer "mailer_port"
    t.string "mailer_protocol"
    t.string "welcome_email_subject"
    t.text "welcome_email_html"
    t.integer "ticket_sla_urgent", default: 4, null: false
    t.integer "ticket_sla_high", default: 8, null: false
    t.integer "ticket_sla_medium", default: 24, null: false
    t.integer "ticket_sla_low", default: 72, null: false
    t.integer "ticket_sla_warn_hours", default: 4, null: false
    t.string "ticket_default_priority", default: "medium", null: false
    t.boolean "ticket_notify_staff", default: true, null: false
    t.boolean "ticket_notify_requester", default: true, null: false
    t.bigint "ticket_default_assignee_id"
    t.integer "ticket_auto_close_days", default: 0, null: false
    t.index ["ticket_default_assignee_id"], name: "index_settings_on_ticket_default_assignee_id"
  end

  create_table "ticket_comments", force: :cascade do |t|
    t.bigint "ticket_id", null: false
    t.bigint "user_id", null: false
    t.text "body", null: false
    t.boolean "internal", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ticket_id"], name: "index_ticket_comments_on_ticket_id"
    t.index ["user_id"], name: "index_ticket_comments_on_user_id"
  end

  create_table "tickets", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "assignee_id"
    t.string "subject", null: false
    t.text "body", null: false
    t.string "status", default: "open", null: false
    t.string "priority", default: "medium", null: false
    t.string "category", default: "other", null: false
    t.integer "sla_hours"
    t.datetime "sla_due_at"
    t.datetime "first_response_at"
    t.datetime "resolved_at"
    t.datetime "closed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assignee_id"], name: "index_tickets_on_assignee_id"
    t.index ["priority"], name: "index_tickets_on_priority"
    t.index ["sla_due_at"], name: "index_tickets_on_sla_due_at"
    t.index ["status"], name: "index_tickets_on_status"
    t.index ["user_id"], name: "index_tickets_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.string "role"
    t.boolean "must_change_password", default: false, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "waitlist_entries", force: :cascade do |t|
    t.bigint "room_id", null: false
    t.bigint "professional_id", null: false
    t.datetime "starts_at", null: false
    t.datetime "ends_at", null: false
    t.string "status", default: "waiting", null: false
    t.datetime "notified_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["professional_id"], name: "index_waitlist_entries_on_professional_id"
    t.index ["room_id", "professional_id", "starts_at"], name: "index_waitlist_unique_waiting", unique: true, where: "((status)::text = 'waiting'::text)"
    t.index ["room_id"], name: "index_waitlist_entries_on_room_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "api_keys", "users"
  add_foreign_key "appointment_notes", "bookings"
  add_foreign_key "appointment_notes", "patients"
  add_foreign_key "audit_events", "users"
  add_foreign_key "bookings", "invoices"
  add_foreign_key "bookings", "patients"
  add_foreign_key "bookings", "professionals"
  add_foreign_key "bookings", "rooms"
  add_foreign_key "invoices", "professionals"
  add_foreign_key "invoices", "rooms"
  add_foreign_key "notifications", "users"
  add_foreign_key "notifications", "users", column: "actor_id"
  add_foreign_key "outbound_emails", "users"
  add_foreign_key "patients", "professionals"
  add_foreign_key "professionals", "users"
  add_foreign_key "room_blocks", "rooms"
  add_foreign_key "settings", "users", column: "ticket_default_assignee_id"
  add_foreign_key "ticket_comments", "tickets"
  add_foreign_key "ticket_comments", "users"
  add_foreign_key "tickets", "users"
  add_foreign_key "tickets", "users", column: "assignee_id"
  add_foreign_key "waitlist_entries", "professionals"
  add_foreign_key "waitlist_entries", "rooms"
end
