FactoryBot.define do
  factory :log_entry do
    user { nil }
    tracker { nil }
    timestamp_utc { "2025-07-22 19:43:31" }
    transcription_text { "MyText" }
    notes { "MyText" }
    audio_file_url { "MyString" }
    duration_seconds { 1 }
    status { "MyString" }
  end
end
