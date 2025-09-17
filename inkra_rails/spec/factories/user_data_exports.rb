FactoryBot.define do
  factory :user_data_export do
    user { nil }
    status { "MyString" }
    s3_key { "MyString" }
    file_count { 1 }
    total_size_bytes { "" }
    highest_project_id { 1 }
    highest_audio_segment_id { 1 }
    created_at { "2025-08-31 20:03:55" }
    updated_at { "2025-08-31 20:03:55" }
    expires_at { "2025-08-31 20:03:55" }
  end
end
