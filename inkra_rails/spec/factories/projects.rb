FactoryBot.define do
  factory :project do
    association :user
    title { "Interview about #{Faker::Company.name}" }
    topic { "A comprehensive interview about #{Faker::Company.industry}" }
    status { "outline_ready" }
    last_modified_at { Time.current }
  end
  
  factory :project_generating, parent: :project do
    status { "outline_generating" }
  end
  
  factory :project_with_outline, parent: :project do
    after(:create) do |project|
      create_list(:chapter_with_sections, 2, project: project)
    end
  end

  trait :recording_in_progress do
    status { "recording_in_progress" }
  end

  trait :transcribing do
    status { "transcribing" }
  end

  trait :completed do
    status { "completed" }
  end

  trait :failed do
    status { "failed" }
  end
end