FactoryBot.define do
  factory :audio_segment do
    association :project
    association :question
    file_name { "#{Faker::Lorem.word}_#{rand(1000)}.mp3" }
    mime_type { "audio/mpeg" }
    duration_seconds { rand(30..180) }
    upload_status { "pending" }
    s3_url { "https://mock-s3-bucket.s3.amazonaws.com/audio_segments/#{id}/#{file_name}" }

    trait :uploaded do
      upload_status { "success" }
    end

    trait :transcribed do
      upload_status { "transcribed" }
      transcription_text { Faker::Lorem.paragraph(sentence_count: 3) }
    end

    trait :failed do
      upload_status { "failed" }
    end

    trait :transcription_failed do
      upload_status { "transcription_failed" }
    end

    trait :without_question do
      question { nil }
    end
  end
end