class DropGenerationTables < ActiveRecord::Migration[7.1]
  def change
    # Drop generation tables in reverse dependency order
    drop_table :generation_schedules, if_exists: true do |t|
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

    drop_table :generation_responses, if_exists: true do |t|
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

    drop_table :generation_questions, if_exists: true do |t|
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

    drop_table :generation_interviews, if_exists: true do |t|
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
  end
end
