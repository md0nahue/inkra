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

ActiveRecord::Schema[7.1].define(version: 2025_09_01_030355) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

  create_table "advisor_interactions", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.string "advisor_id", null: false
    t.text "question", null: false
    t.text "response"
    t.string "status", default: "pending"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "advisor_id"], name: "index_advisor_interactions_on_project_id_and_advisor_id"
    t.index ["project_id"], name: "index_advisor_interactions_on_project_id"
  end

  create_table "audio_segments", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "question_id"
    t.string "file_name"
    t.string "mime_type"
    t.integer "duration_seconds"
    t.string "s3_url"
    t.string "upload_status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "transcription_text"
    t.jsonb "transcription_data"
    t.index ["project_id"], name: "index_audio_segments_on_project_id"
    t.index ["question_id"], name: "index_audio_segments_on_question_id"
  end

  create_table "chapters", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.string "title"
    t.integer "order"
    t.boolean "omitted"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_chapters_on_project_id"
  end

  create_table "device_logs", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "s3_url"
    t.string "device_id"
    t.string "build_version"
    t.string "os_version"
    t.datetime "uploaded_at"
    t.string "log_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_device_logs_on_user_id"
  end

  create_table "feedbacks", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.text "feedback_text", null: false
    t.string "feedback_type", default: "general"
    t.string "email"
    t.boolean "resolved", default: false
    t.text "admin_notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_feedbacks_on_created_at"
    t.index ["feedback_type"], name: "index_feedbacks_on_feedback_type"
    t.index ["resolved"], name: "index_feedbacks_on_resolved"
    t.index ["user_id"], name: "index_feedbacks_on_user_id"
  end

  create_table "generation_interviews", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "speaker_id", null: false
    t.string "title", null: false
    t.text "topic"
    t.string "narrative_perspective", default: "second_person"
    t.string "magic_link_token", null: false
    t.string "status", default: "draft"
    t.datetime "last_sent_at"
    t.boolean "email_enabled", default: true
    t.boolean "sms_enabled", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["magic_link_token"], name: "index_generation_interviews_on_magic_link_token", unique: true
    t.index ["speaker_id"], name: "index_generation_interviews_on_speaker_id"
    t.index ["status"], name: "index_generation_interviews_on_status"
    t.index ["user_id", "speaker_id"], name: "index_generation_interviews_on_user_id_and_speaker_id"
    t.index ["user_id"], name: "index_generation_interviews_on_user_id"
  end

  create_table "generation_questions", force: :cascade do |t|
    t.bigint "generation_interview_id", null: false
    t.text "text", null: false
    t.integer "order_position", null: false
    t.string "chapter_title"
    t.string "section_title"
    t.boolean "ai_generated", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["generation_interview_id", "order_position"], name: "idx_gen_questions_interview_order", unique: true
    t.index ["generation_interview_id"], name: "index_generation_questions_on_generation_interview_id"
  end

  create_table "generation_responses", force: :cascade do |t|
    t.bigint "generation_interview_id", null: false
    t.bigint "generation_question_id", null: false
    t.bigint "speaker_id", null: false
    t.string "audio_url", null: false
    t.text "transcript"
    t.text "polished_text"
    t.string "status", default: "recording"
    t.integer "duration_seconds"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["generation_interview_id"], name: "index_generation_responses_on_generation_interview_id"
    t.index ["generation_question_id", "created_at"], name: "idx_gen_responses_question_created"
    t.index ["generation_question_id"], name: "index_generation_responses_on_generation_question_id"
    t.index ["speaker_id"], name: "index_generation_responses_on_speaker_id"
    t.index ["status"], name: "index_generation_responses_on_status"
  end

  create_table "generation_schedules", force: :cascade do |t|
    t.bigint "generation_interview_id", null: false
    t.datetime "scheduled_at", null: false
    t.string "frequency", default: "once"
    t.string "day_of_week"
    t.string "time_of_day"
    t.string "time_zone", default: "UTC"
    t.string "status", default: "pending"
    t.datetime "sent_at"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["generation_interview_id", "status"], name: "idx_gen_schedules_interview_status"
    t.index ["generation_interview_id"], name: "index_generation_schedules_on_generation_interview_id"
    t.index ["scheduled_at"], name: "index_generation_schedules_on_scheduled_at"
    t.index ["status"], name: "index_generation_schedules_on_status"
  end

  create_table "interview_presets", force: :cascade do |t|
    t.string "title", null: false
    t.text "description", null: false
    t.string "category", null: false
    t.string "icon_name", null: false
    t.integer "order_position", default: 0
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_featured", default: false, null: false
    t.uuid "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.index ["active"], name: "index_interview_presets_on_active"
    t.index ["category"], name: "index_interview_presets_on_category"
    t.index ["order_position"], name: "index_interview_presets_on_order_position"
    t.index ["uuid"], name: "index_interview_presets_on_uuid", unique: true
  end

  create_table "log_entries", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "tracker_id", null: false
    t.datetime "timestamp_utc"
    t.text "transcription_text"
    t.text "notes"
    t.string "audio_file_url"
    t.integer "duration_seconds"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tracker_id"], name: "index_log_entries_on_tracker_id"
    t.index ["user_id"], name: "index_log_entries_on_user_id"
  end

  create_table "polly_audio_clips", force: :cascade do |t|
    t.bigint "question_id", null: false
    t.string "s3_key"
    t.string "voice_id", null: false
    t.integer "speech_rate", default: 100
    t.string "language_code", default: "en-US"
    t.integer "duration_ms"
    t.string "status", default: "pending", null: false
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "content_type"
    t.integer "request_characters"
    t.index ["question_id"], name: "index_polly_audio_clips_on_question_id"
    t.index ["s3_key"], name: "index_polly_audio_clips_on_s3_key", unique: true
    t.index ["status"], name: "index_polly_audio_clips_on_status"
  end

  create_table "preset_questions", force: :cascade do |t|
    t.bigint "interview_preset_id", null: false
    t.string "chapter_title", null: false
    t.string "section_title", null: false
    t.text "question_text", null: false
    t.integer "chapter_order", null: false
    t.integer "section_order", null: false
    t.integer "question_order", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["interview_preset_id", "chapter_order", "section_order", "question_order"], name: "index_preset_questions_on_ordering"
    t.index ["interview_preset_id"], name: "index_preset_questions_on_interview_preset_id"
  end

  create_table "projects", force: :cascade do |t|
    t.string "title"
    t.string "status"
    t.text "topic"
    t.datetime "last_modified_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.boolean "is_speech_interview", default: false, null: false
    t.bigint "interview_preset_id"
    t.boolean "is_template", default: false
    t.string "template_name"
    t.text "template_description"
    t.string "voice_id"
    t.integer "speech_rate", default: 100
    t.datetime "last_accessed_at"
    t.uuid "shareable_token", default: -> { "gen_random_uuid()" }
    t.boolean "is_public", default: false, null: false
    t.string "public_title"
    t.text "public_description"
    t.string "interview_length"
    t.integer "question_count"
    t.index ["interview_preset_id"], name: "index_projects_on_interview_preset_id"
    t.index ["is_template"], name: "index_projects_on_is_template"
    t.index ["last_accessed_at"], name: "index_projects_on_last_accessed_at"
    t.index ["shareable_token"], name: "index_projects_on_shareable_token", unique: true
    t.index ["user_id"], name: "index_projects_on_user_id"
  end

  create_table "questions", force: :cascade do |t|
    t.bigint "section_id", null: false
    t.text "text"
    t.integer "order"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "parent_question_id"
    t.boolean "is_follow_up", default: false, null: false
    t.boolean "omitted", default: false, null: false
    t.boolean "skipped", default: false, null: false
    t.index ["parent_question_id"], name: "index_questions_on_parent_question_id"
    t.index ["section_id"], name: "index_questions_on_section_id"
  end

  create_table "sections", force: :cascade do |t|
    t.bigint "chapter_id", null: false
    t.string "title"
    t.integer "order"
    t.boolean "omitted"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chapter_id"], name: "index_sections_on_chapter_id"
  end

  create_table "speakers", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.string "email"
    t.string "phone_number"
    t.string "pronoun"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_speakers_on_email"
    t.index ["user_id", "name"], name: "index_speakers_on_user_id_and_name"
    t.index ["user_id"], name: "index_speakers_on_user_id"
  end

  create_table "trackers", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name"
    t.string "sf_symbol_name"
    t.string "color_hex"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_accessed_at"
    t.index ["last_accessed_at"], name: "index_trackers_on_last_accessed_at"
    t.index ["user_id"], name: "index_trackers_on_user_id"
  end

  create_table "transcripts", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.string "status"
    t.text "edited_content"
    t.datetime "last_updated"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "raw_structured_content"
    t.text "raw_content"
    t.text "polished_content"
    t.index ["project_id"], name: "index_transcripts_on_project_id"
  end

  create_table "user_data_exports", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "status", default: "pending", null: false
    t.string "s3_key"
    t.integer "file_count", default: 0
    t.bigint "total_size_bytes", default: 0
    t.integer "highest_project_id"
    t.integer "highest_audio_segment_id"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_user_data_exports_on_expires_at"
    t.index ["status"], name: "index_user_data_exports_on_status"
    t.index ["user_id", "created_at"], name: "index_user_data_exports_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_user_data_exports_on_user_id"
  end

  create_table "user_shown_interview_presets", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "interview_preset_id", null: false
    t.datetime "shown_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shown_at"], name: "index_user_shown_interview_presets_on_shown_at"
    t.index ["user_id", "interview_preset_id"], name: "index_user_shown_interview_presets_unique", unique: true
    t.index ["user_id"], name: "index_user_shown_interview_presets_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "refresh_token_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "admin", default: false, null: false
    t.string "interests", default: [], array: true
    t.index ["admin"], name: "index_users_on_admin"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["interests"], name: "index_users_on_interests", using: :gin
  end

  add_foreign_key "advisor_interactions", "projects"
  add_foreign_key "audio_segments", "projects"
  add_foreign_key "audio_segments", "questions"
  add_foreign_key "chapters", "projects"
  add_foreign_key "device_logs", "users"
  add_foreign_key "feedbacks", "users"
  add_foreign_key "generation_interviews", "speakers"
  add_foreign_key "generation_interviews", "users"
  add_foreign_key "generation_questions", "generation_interviews"
  add_foreign_key "generation_responses", "generation_interviews"
  add_foreign_key "generation_responses", "generation_questions"
  add_foreign_key "generation_responses", "speakers"
  add_foreign_key "generation_schedules", "generation_interviews"
  add_foreign_key "log_entries", "trackers"
  add_foreign_key "log_entries", "users"
  add_foreign_key "polly_audio_clips", "questions"
  add_foreign_key "preset_questions", "interview_presets"
  add_foreign_key "projects", "users"
  add_foreign_key "questions", "questions", column: "parent_question_id"
  add_foreign_key "questions", "sections"
  add_foreign_key "sections", "chapters"
  add_foreign_key "speakers", "users"
  add_foreign_key "trackers", "users"
  add_foreign_key "transcripts", "projects"
  add_foreign_key "user_data_exports", "users"
  add_foreign_key "user_shown_interview_presets", "interview_presets"
  add_foreign_key "user_shown_interview_presets", "users"
end
